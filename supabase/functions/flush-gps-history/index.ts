// Private GPS archiver. The handler checks exact server-side secrets itself.
import { createGpsArchiveHandler } from "./archive.mjs";

Deno.serve(createGpsArchiveHandler({ getEnv: (name: string) => Deno.env.get(name) }));
