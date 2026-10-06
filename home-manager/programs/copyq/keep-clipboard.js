const keepClipboardAlive = () => {
    if (!isClipboard() || !hasData()) return;

    const clipboardTimestamp = str(clipboard("TIMESTAMP").toBase64());
    const isClipboardSecret = str(clipboard("x-kde-passwordManagerHint")) === "secret";
    if (isClipboardSecret) return;

    const formats = new Set(str(clipboard("?")).split("\n"));
    const item = {};

    for (const format of formats) {
        const isContentFormat = /^[a-z]/.test(format)
            && !format.startsWith("application/x-copyq-");
        if (!isContentFormat) continue;

        item[format] = clipboard(format);
    }

    if (Object.keys(item).length === 0) return;
    if (str(clipboard("TIMESTAMP").toBase64()) !== clipboardTimestamp) return;

    copy(item);
};

keepClipboardAlive();
