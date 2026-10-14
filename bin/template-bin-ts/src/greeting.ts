export const createGreeting = (name: string, isExcited = false) => {
  const trimmedName = name.trim();
  const suffix = isExcited ? "!" : "";

  return { message: `hello ${trimmedName}${suffix}` };
};
