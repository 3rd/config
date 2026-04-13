{
  piper-tts,
  voicePackage,
  modelPath,
  writeShellApplication,
}:

writeShellApplication {
  name = "piper-libritts-r";
  runtimeInputs = [ piper-tts ];
  meta.mainProgram = "piper-libritts-r";
  text = ''
    exec ${piper-tts}/bin/piper \
      --model ${voicePackage}/share/piper-voices/${modelPath} \
      "$@"
  '';
}
