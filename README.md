# Introduction

This is a set of tools for standing up a simple seedbox mirror for the ravynOS nightly ISOs.

It could, in theory, also be used for release ISOs as well, when the time comes.

# Usage

## Transmission

First, set up Transmission.
The seeding script assumes it is what you're using for torrents.

1. Make sure local auth is disabled (`"rpc-authentication-required": false`), or that you have properly set up RPC auth and a `.netrc` file or similar.
2. Make sure limits are such that seeding will not stop, and that all seeds will be actively downloadable from the default directory.
   * `"download-limit-enabled": 0`
   * `"download-queue-enabled": false`
   * `"idle-seeding-limit-enabled": false`
   * `"incomplete-dir-enabled": false`
   * `"queue-stalled-enabled": false`
   * `"ratio-limit-enabled": false`
   * `"seed-queue-enabled": false`
   * `"start-added-torrents": true`
   * `"trash-original-torrent-files": false`
   * `"upload-limit-enabled": 0`

## Configure the Source and Target

Copy `env.sample` to `env` and edit to match your environment.

By default it will sync from the ravynOS upstream mirror, to the `./nightly` directory.

## Running an Update

Run `./update.sh` to sync, generate torrents, and start seeding them.

This is just a wrapper for the individual sync, torrent-generation, and seeding scripts, if you wish to do only part of the process.
