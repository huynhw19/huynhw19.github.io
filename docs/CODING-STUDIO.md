# ConfigKit Coding Studio

ConfigKit Coding Studio is an in-site visual programming workspace at
[https://huynhw19.github.io/coding-studio.html](https://huynhw19.github.io/coding-studio.html).

## What it includes

- Blockly visual programming with Logic, Loops, Math, Text, Lists, Colour, Variables and Functions.
- JavaScript and Python code generation from the same block workspace.
- A JavaScript runner isolated in a sandboxed iframe with a restrictive Content Security Policy and a five-second run limit.
- Program output, code copy and code download.
- Browser-local project save/open and portable JSON import/export.
- Starter project and responsive layout for desktop and mobile.

## Project storage and privacy

The editor stores saved projects in the browser's local storage on the current device and browser profile. It does not upload block workspaces to ConfigKit Drive or Supabase. Export a JSON project file to back it up or move it to another browser. Clearing site data can remove locally saved projects.

The Blockly library is loaded from the unpkg CDN. An internet connection is required for the editor to initialize.

## Scope

Coding Studio is an original ConfigKit workspace powered by Blockly, rather than a fork of Scratch. It provides block-based programming and text-code generation. It does not currently run Python in the browser, implement Scratch sprites/stage/audio, or synchronize saved workspaces to a ConfigKit account.
