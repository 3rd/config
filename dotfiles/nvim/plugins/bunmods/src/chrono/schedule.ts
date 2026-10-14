import { parse } from "chrono-node";

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

const isSameDay = (first: Date, second: Date) => {
  return (
    first.getFullYear() === second.getFullYear() &&
    first.getMonth() === second.getMonth() &&
    first.getDate() === second.getDate()
  );
};

export const parseSchedule = (input: string, reference = new Date()) => {
  const numberValue = Number(input);
  if (!Number.isNaN(numberValue)) {
    return `${formatDate(reference)} ${numberValue}:00`;
  }

  const [firstResult] = parse(input, reference);
  if (!firstResult) return null;

  const startDate = firstResult.start.date();
  const endDate = firstResult.end?.date();
  const isTimeSpecific = firstResult.start.isCertain("hour") && firstResult.start.isCertain("minute");

  let startText = formatDate(startDate);
  if (isTimeSpecific) {
    startText += ` ${formatTime(startDate)}`;
  }

  if (!endDate) return startText;
  if (isSameDay(startDate, endDate)) {
    return `${startText}-${formatTime(endDate)}`;
  }

  return `${startText} - ${formatDate(endDate)} ${formatTime(endDate)}`;
};
