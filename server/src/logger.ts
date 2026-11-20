export interface Logger {
  info(obj: object, msg: string): void;
  warn(obj: object, msg: string): void;
  error(obj: object, msg: string): void;
}

function write(level: string, obj: object, msg: string): void {
  const line = JSON.stringify({ level, time: new Date().toISOString(), msg, ...obj });
  (level === "info" ? console.log : console.error)(line);
}

export const logger: Logger = {
  info: (obj, msg) => write("info", obj, msg),
  warn: (obj, msg) => write("warn", obj, msg),
  error: (obj, msg) => write("error", obj, msg),
};
