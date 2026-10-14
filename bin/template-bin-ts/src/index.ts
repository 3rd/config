#!/usr/bin/env bun

import { runCli } from "./cli";
import { handleCliError } from "./errors";

if (import.meta.main) {
  runCli().catch(handleCliError);
}
