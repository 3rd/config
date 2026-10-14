import type { BufferEvent, BufferSubscription, PluginSetup } from "../../src";
import { isRecord, requireInteger, requireString } from "../../src/rpc/protocol";

interface SubscriptionState {
  events: BufferEvent[];
  reason?: string;
  error?: string;
  isWaiting: boolean;
  wasAborted: boolean;
}

const setup: PluginSetup = async (context) => {
  const subscriptions = new Map<string, BufferSubscription>();
  const releases = new Map<string, () => void>();
  const states: Record<string, SubscriptionState> = {};
  const publish = () => context.nvim.setVar(`bunvim_subscriptions_${  context.name}`, states);

  const subscribe = async (input: unknown) => {
    if (!isRecord(input)) {
      throw new Error("Expected subscription options");
    }

    const name = requireString(input.name, "name");
    const buffer = requireInteger(input.buffer, "buffer");
    const behavior = input.behavior;
    const maxQueued =
      input.maxQueued === undefined ? undefined : requireInteger(input.maxQueued, "maxQueued");
    const state: SubscriptionState = {
      events: [],
      isWaiting: false,
      wasAborted: false,
    };
    states[name] = state;
    const subscription = context.subscribeBuffer({ buffer, maxQueued }, async (event, invocation) => {
      state.events.push(event);
      if (event.type === "lines" && behavior === "fail") {
        throw new Error("subscription handler failure");
      }

      if (event.type === "lines" && behavior === "self-dispose") {
        await subscription.dispose();
        state.wasAborted = invocation.signal.aborted;
      }

      if (event.type === "lines" && behavior === "hold") {
        const release = Promise.withResolvers<void>();
        releases.set(name, release.resolve);
        const abort = () => {
          state.wasAborted = true;
          release.resolve();
        };
        invocation.signal.addEventListener("abort", abort, { once: true });
        state.isWaiting = true;
        await publish();
        await release.promise;
        invocation.signal.removeEventListener("abort", abort);
        state.isWaiting = false;
        releases.delete(name);
      }

      if (event.type === "lines" && behavior === "uncooperative") {
        state.isWaiting = true;
        await publish();
        await new Promise(() => {});
      }

      await publish();
    });
    subscriptions.set(name, subscription);
    subscription.closed.then(async (result) => {
      state.reason = result.reason;
      if (result.reason === "error") {
        state.error = result.error.message;
      }

      await publish();
    });
    await subscription.ready;
    return true;
  };

  context.registerFunction("subscribe", subscribe);
  context.registerFunction("dispose", async (input) => {
    const name = requireString(input, "name");
    const subscription = subscriptions.get(name);
    if (!subscription) {
      throw new Error("Unknown subscription");
    }

    await subscription.dispose();
    await publish();
    return true;
  });
  context.registerFunction("release", (input) => {
    const name = requireString(input, "name");
    const release = releases.get(name);
    if (!release) {
      throw new Error("Subscription is not waiting");
    }

    release();
    return true;
  });
  context.registerFunction("state", async () => {
    await publish();
    return true;
  });
  context.onDispose(async () => {
    await context.nvim.setVar(`bunvim_subscriptions_disposed_${  context.name}`, true);
  });

  if (isRecord(context.options)) {
    await subscribe(context.options);
    if (context.options.shouldFail) {
      throw new Error("subscription setup failure");
    }
  }
};

export default setup;
