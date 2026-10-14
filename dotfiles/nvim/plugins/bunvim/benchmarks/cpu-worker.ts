import { parentPort, workerData } from "node:worker_threads";

const duration: unknown = workerData;
if (!parentPort || typeof duration !== "number" || !Number.isFinite(duration) || duration <= 0) {
  throw new Error("CPU benchmark requires a positive duration and a worker thread");
}

parentPort.postMessage("started");
const deadline = performance.now() + duration;
let result = 0;
while (performance.now() < deadline) {
  for (let index = 0; index < 10_000; index += 1) {
    result += Math.sqrt(index);
  }
}

parentPort.postMessage(result);
