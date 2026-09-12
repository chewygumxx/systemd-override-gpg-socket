// vim:set expandtab shiftwidth=4 filetype=javascript:
// SPDX-License-Identifier: GPL-3.0-only

//
//
// ~chewygumxx/systemd-override-gpg-socket.git
// ::: :/commitlint.config.mjs
//
//

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const meteor = JSON.parse(readFileSync(join(__dirname, ".meteor.json"), "utf8"));

export default {
    extends: ["@commitlint/config-conventional"],
    rules: {
        "type-enum": [2, "always", meteor.prefixes.map((p) => p.type)],
        "header-max-length": [2, "always", meteor.commitTitleCharLimit],
        "body-max-line-length": [2, "always", meteor.commitBodyLineLength],
        "scope-enum": meteor.allowCustomScopes ? [0] : [2, "always", meteor.scopes],
        "subject-case": [2, "always", "sentence-case"],
    },
};
