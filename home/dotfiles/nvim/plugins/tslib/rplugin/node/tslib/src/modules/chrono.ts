import * as chrono from "chrono-node";
import { RPCFunction } from "../types";

const formatDate = (date: Date) => {
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, "0");
  const dd = String(date.getDate()).padStart(2, "0");
  return `${yyyy}.${mm}.${dd}`;
};

const formatTime = (date: Date) => {
  const hh = String(date.getHours()).padStart(2, "0");
  const mm = String(date.getMinutes()).padStart(2, "0");
  return `${hh}:${mm}`;
};

const isSameDay = (d1: Date, d2: Date) => {
  return d1.getFullYear() === d2.getFullYear() && d1.getMonth() === d2.getMonth() && d1.getDate() === d2.getDate();
};

export const toSchedule: RPCFunction<string> = ({ input }) => {
  const parsedResults = chrono.parse(input);
  if (parsedResults.length === 0) return null;

  const firstResult = parsedResults[0];
  const startDate = firstResult.start.date();
  const endDate = firstResult.end?.date();

  const isTimeSpecific = firstResult.start.isCertain("hour") && firstResult.start.isCertain("minute");

  let startStr = formatDate(startDate);
  if (isTimeSpecific) {
    startStr += ` ${formatTime(startDate)}`;
  }

  if (endDate) {
    if (isSameDay(startDate, endDate)) {
      return `${startStr}-${formatTime(endDate)}`;
    }
    return `${startStr} - ${formatDate(endDate)} ${formatTime(endDate)}`;
  }
  return startStr;
};
