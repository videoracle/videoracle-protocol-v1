import fs from "fs";
import path from "path";

export enum ConfigProperty {
  VideOracle = "videOracleAddress",
}

const getFilename = (network: string) =>
  path.resolve(__dirname, `../configs/${network}.json`);

const loadJSON = (network: string) => {
  const filename = getFilename(network);
  return fs.existsSync(filename) ? fs.readFileSync(filename).toString() : "{}";
};

const saveJSON = (network: string, json = "") => {
  const filename = getFilename(network);
  return fs.writeFileSync(filename, JSON.stringify(json, null, 2));
};

export const get = (network: string, property: ConfigProperty): string => {
  const obj = JSON.parse(loadJSON(network));
  return obj[property] || "Not found";
};

export const set = (
  network: string,
  property: ConfigProperty,
  value: string
) => {
  const obj = JSON.parse(loadJSON(network) || "{}");
  obj[property] = value;
  saveJSON(network, obj);
};

export const remove = (network: string, property: ConfigProperty) => {
  const obj = JSON.parse(loadJSON(network) || "{}");
  delete obj[property];
  saveJSON(network, obj);
};
