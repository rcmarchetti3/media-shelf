/** RAWG's free API tier requires a visible link back wherever its data is shown. */
export function RawgCredit({ className = "" }: { className?: string }) {
  return (
    <p className={`text-xs text-muted-foreground ${className}`}>
      Game data from{" "}
      <a
        href="https://rawg.io"
        target="_blank"
        rel="noopener noreferrer"
        className="text-primary underline-offset-4 hover:underline"
      >
        RAWG
      </a>
    </p>
  );
}
