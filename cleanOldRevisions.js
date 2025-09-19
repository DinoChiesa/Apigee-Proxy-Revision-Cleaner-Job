#! /usr/local/bin/node
/* jshint node:true, esversion:9, strict:implied */
// cleanOldRevisions.js
// ------------------------------------------------------------------
// In Apigee, for all proxies and sharedflows in an org, remove all
// but the latest N revisions. (Never remove a deployed revision).
//
// Copyright 2017-2023,2025 Google LLC.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// last saved: <2025-September-18 18:06:35>

import apigeejs from "apigee-edge-js";
import Getopt from "node-getopt";
import util from "util";
import pLimit from "p-limit";

const common = apigeejs.utility,
  apigee = apigeejs.apigee,
  version = "20250918-1735",
  getopt = new Getopt(
    common.commonOptions.concat([
      [
        "R",
        "regexp=ARG",
        "Optional. Cull only proxies with names matching this regexp.",
      ],
      [
        "K",
        "numToKeep=ARG",
        "Required. Max number of revisions of each proxy to retain.",
      ],
      [
        "",
        "collection=ARG",
        "Optional. Collection to cull. Either sharedflows or apiproxies. Default: both",
      ],
      [
        "",
        "magictoken",
        "Optional. Obtain a magic token from http://metadata.google.internal",
      ],
    ]),
  ).bindHelp();

const getMagicToken = async () => {
  const response = await fetch(
    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token",
    {
      method: "GET",
      headers: { "Metadata-Flavor": "Google" },
    },
  );
  const data = await response.json();
  return data.access_token;
};

// ========================================================
process.on("unhandledRejection", (r) =>
  console.log("\n*** unhandled promise rejection: " + util.format(r)),
);

const isDeployed = (result) =>
  (result.environment && result.environment.length != 0) || result.deployments;

const opt = getopt.parse(
  process.env.CMDARGS
    ? process.env.CMDARGS.split(new RegExp(" +", "g"))
    : process.argv.slice(2),
);

if (opt.options.verbose) {
  console.log(
    `Apigee Proxy / Sharedflow revision cleaner tool, version: ${version}\n` +
      `Node.js ${process.version}\n`,
  );
  common.logWrite("start");
}

if (opt.options.magictoken) {
  opt.options.token = await getMagicToken();
  if (!opt.options.token) {
    console.log("could not get magic token\n");
    process.exit(1);
  }
}

async function examineRevisions(collection, name, revisions) {
  if (opt.options.verbose) {
    common.logWrite("revisions %s: %s", name, JSON.stringify(revisions));
  }
  if (revisions && revisions.length > opt.options.numToKeep) {
    revisions.sort((a, b) => a - b);

    let reducer = (promise, c, _ix, orig) =>
      promise.then((a) => {
        if (a.length >= orig.length - opt.options.numToKeep) {
          return a;
        }
        const options = { name, revision: c };
        return collection.getDeployments(options).then((result) => {
          if (opt.options.verbose) {
            common.logWrite(
              "deployments (%s r%s): %s",
              name,
              c,
              JSON.stringify(result),
            );
          }
          return isDeployed(result) ? a : [...a, c];
        });
      });

    let revisionsToRemove = await revisions.reduce(
      reducer,
      Promise.resolve([]),
    );

    // limit the number of concurrent requests
    const limit = pLimit(4);

    const concurrentDeleter = (revision) =>
      limit((_) => collection.del({ name, revision }).then((_) => revision));

    return Promise.all(revisionsToRemove.map(concurrentDeleter)).then(
      (revisions) => {
        revisions = revisions.filter((r) => r);
        if (revisions.length) {
          if (opt.options.verbose) {
            common.logWrite("deleted %s: %s", name, JSON.stringify(revisions));
          }
          return { item: name, revisions };
        }
        return null;
      },
    );
  }
  return null;
}

function validateCollection(v) {
  const allowedValues = ["sharedflows", "proxies", "apiproxies"];

  // First, check if the input string is one of the allowed values
  if (!allowedValues.includes(v)) {
    // If not, it fails the check, return an empty array or handle as an error
    return null;
  }

  // Map "apiproxies" to "proxies", wrap in an array
  return [v === "apiproxies" ? "proxies" : v];
}

common.verifyCommonRequiredParameters(opt.options, getopt);

if (!opt.options.numToKeep) {
  console.log(
    "You must specify a number of revisions to retain. (-K) There is no default.",
  );
  getopt.showHelp();
  process.exit(1);
}

const collectionNames = opt.options.collection
  ? validateCollection(opt.options.collection)
  : ["sharedflows", "proxies"];

if (!collectionNames) {
  console.log("You must specify a valid option for --collection");
  getopt.showHelp();
  process.exit(1);
}

apigee
  .connect(common.optToOptions(opt))
  .then((org) => {
    const readOptions = {};
    const doOneCollection = (collectionName) => {
      const collection = org[collectionName];
      return collection.get(readOptions).then((results) => {
        if (results) {
          // convert for GAAMBO
          if (results.proxies && results.proxies.length) {
            results = results.proxies.map((r) => r.name);
          }
          if (results.sharedFlows && results.sharedFlows.length) {
            results = results.sharedFlows.map((r) => r.name);
          }
        }
        if (opt.options.regexp) {
          const re1 = new RegExp(opt.options.regexp);
          results = results.filter((item) => re1.test(item));
        }
        if (!results || results.length == 0) {
          common.logWrite(
            "No %s%s",
            opt.options.regexp ? "matching " : "",
            collectionName,
          );
          return Promise.resolve(true);
        }

        if (opt.options.verbose) {
          console.log(JSON.stringify(results, null, 2));
          common.logWrite(
            "found %d %s%s",
            results.length,
            opt.options.regexp ? "matching " : "",
            collectionName,
          );
        }

        const reducer = (promise, itemname) =>
          promise.then((accumulator) =>
            collection.getRevisions({ name: itemname }).then(async (r) => {
              const x = await examineRevisions(collection, itemname, r);
              accumulator.push(x);
              return accumulator;
            }),
          );

        return results.reduce(reducer, Promise.resolve([]));
      });
    };

    const r = (promise, item) =>
      promise.then(async (accumulator) => {
        const x = await doOneCollection(item);
        accumulator.push(x);
        return accumulator;
      });

    return collectionNames.reduce(r, Promise.resolve([])).then((a) => {
      a = a.map((innerArray) => innerArray.filter((item) => item !== null));
      if (opt.options.verbose) {
        common.logWrite("summary deleted: " + JSON.stringify(a));
      }
    });
  })
  .catch((e) => console.error("error: " + util.format(e)));
