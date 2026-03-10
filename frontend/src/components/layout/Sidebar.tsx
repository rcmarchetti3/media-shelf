import { Link, useLocation } from "react-router-dom";
import { cn } from "@/lib/utils";
import { Logo } from "./Logo";
import {
  topNavItems,
  collectionNavItems,
  bottomNavItems,
  icons,
} from "./nav-items";

export function Sidebar() {
  const location = useLocation();
  const searchParams = new URLSearchParams(location.search);
  const currentType = searchParams.get("type");

  const renderIcon = (iconName: string) => (
    <svg
      className="h-5 w-5"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={1.5}
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d={icons[iconName]}
      />
    </svg>
  );

  return (
    <aside className="hidden md:flex w-64 flex-col border-r border-border bg-card">
      <div className="p-6">
        <Logo />
      </div>
      <nav className="flex-1 px-3 space-y-1">
        {topNavItems.map((item) => {
          const isActive =
            item.path === "/"
              ? location.pathname === "/"
              : location.pathname.startsWith(item.path);

          return (
            <Link
              key={item.path}
              to={item.path}
              className={cn(
                "flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
                isActive
                  ? "bg-accent text-accent-foreground"
                  : "text-muted-foreground hover:bg-accent hover:text-accent-foreground"
              )}
            >
              {renderIcon(item.icon)}
              {item.label}
            </Link>
          );
        })}

        {/* Collection section */}
        <div className="pt-4">
          <p className="px-3 pb-1 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            Collection
          </p>
          {collectionNavItems.map((item) => {
            const path =
              item.type === "all"
                ? "/collection"
                : `/collection?type=${item.type}`;
            const isActive =
              item.type === "all"
                ? location.pathname.startsWith("/collection") && !currentType
                : location.pathname === "/collection" &&
                  currentType === item.type;

            return (
              <Link
                key={item.type}
                to={path}
                className={cn(
                  "flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
                  isActive
                    ? "bg-accent text-accent-foreground"
                    : "text-muted-foreground hover:bg-accent hover:text-accent-foreground"
                )}
              >
                {renderIcon(item.icon)}
                {item.label}
              </Link>
            );
          })}
        </div>

        {/* Bottom items */}
        <div className="pt-4">
          {bottomNavItems.map((item) => {
            const isActive = location.pathname.startsWith(item.path);

            return (
              <Link
                key={item.path}
                to={item.path}
                className={cn(
                  "flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
                  isActive
                    ? "bg-accent text-accent-foreground"
                    : "text-muted-foreground hover:bg-accent hover:text-accent-foreground"
                )}
              >
                {renderIcon(item.icon)}
                {item.label}
              </Link>
            );
          })}
        </div>
      </nav>
    </aside>
  );
}
