import { renderTypeDocumentation } from "./type-conversion";

export type VimNamespace = {
  children: Map<string, VimNamespace>;
  signatures: string[];
  value?: number | string;
  documentation?: string;
  unsupported?: string;
};

export const ensureVimNamespace = (root: VimNamespace, path: string[]) => {
  let namespace = root;

  for (const part of path) {
    let child = namespace.children.get(part);
    if (!child) {
      child = { children: new Map(), signatures: [] };
      namespace.children.set(part, child);
    }

    namespace = child;
  }

  return namespace;
};

export const renderNamespace = (namespace: VimNamespace) => {
  if (namespace.value !== undefined) return JSON.stringify(namespace.value);
  if (namespace.unsupported && namespace.children.size === 0) return "never";

  const functions = [...new Set(namespace.signatures)].map((signature) => `(${signature})`);
  const entries = [...namespace.children].sort(([left], [right]) => left.localeCompare(right));
  if (entries.length > 0) {
    const properties = entries.map(([name, child]) => {
      const documentation = child.documentation ?? "";
      const unsupported =
        child.unsupported ?
          renderTypeDocumentation([{ type: "doc.comment", description: child.unsupported }])
        : "";
      return `${documentation}${unsupported}${JSON.stringify(name)}: ${renderNamespace(child)};`;
    });
    functions.push(`{\n${properties.join("\n")}\n}`);
  }

  return functions.join(" & ");
};
