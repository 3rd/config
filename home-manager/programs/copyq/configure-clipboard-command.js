global.configureClipboardCommand = (clipboardScript) => {
    const clipboardCommand = {
        name: "Keep clipboard alive",
        internalId: "home_manager_keep_clipboard_alive",
        automatic: true,
        enable: true,
        cmd: `copyq:\nsource(${JSON.stringify(clipboardScript)});`,
    };
    const configuredCommands = commands();
    const commandIndex = configuredCommands.findIndex(
        (command) => command.internalId === clipboardCommand.internalId,
    );
    if (commandIndex === -1) {
        configuredCommands.push(clipboardCommand);
    } else {
        const hasSameCommand = exportCommands([configuredCommands[commandIndex]])
            === exportCommands([clipboardCommand]);
        if (hasSameCommand) return;

        configuredCommands[commandIndex] = clipboardCommand;
    }

    setCommands(configuredCommands);
};
