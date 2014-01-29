#!/usr/bin/env node
// Enable auto-compilation via require
require("coffee-script/register");
// Launch Enfield
require("../src/enfield").main(process.argv)
