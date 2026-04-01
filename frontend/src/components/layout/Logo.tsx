import { Link } from "react-router-dom";
import { cn } from "@/lib/utils";

interface LogoProps {
  className?: string;
  iconOnly?: boolean;
}

export function Logo({ className, iconOnly = false }: LogoProps) {
  return (
    <Link
      to="/"
      className={cn("flex items-center gap-2.5 group", className)}
    >
      <svg
        viewBox="0 0 32 32"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        className="h-7 w-7 shrink-0"
      >
        {/* Shelf base */}
        <rect x="3" y="24" width="26" height="2.5" rx="1" className="fill-primary" />
        {/* Left book */}
        <rect x="6" y="8" width="4" height="16" rx="1" className="fill-primary" />
        {/* Middle vinyl record */}
        <circle cx="16" cy="16" r="5.5" className="stroke-primary" strokeWidth="2" />
        <circle cx="16" cy="16" r="1.5" className="fill-primary" />
        {/* Right book */}
        <rect x="22" y="10" width="4" height="14" rx="1" className="fill-primary" />
        {/* Film strip accents */}
        <rect x="23" y="11" width="2" height="1.5" rx="0.3" className="fill-background" opacity="0.6" />
        <rect x="23" y="13.5" width="2" height="1.5" rx="0.3" className="fill-background" opacity="0.6" />
      </svg>
      {!iconOnly && (
        <span className="text-xl font-bold tracking-tight text-brass" style={{fontFamily: "var(--font-heading)"}}>
          MediaShelf
        </span>
      )}
    </Link>
  );
}
