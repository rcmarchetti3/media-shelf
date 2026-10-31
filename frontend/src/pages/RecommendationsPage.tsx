import { RecommendedShelf } from "@/components/RecommendedShelf";

export function RecommendationsPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">For You</h1>
        <p className="text-muted-foreground">
          Picks based on what you rate highly and finish. Add one and it lands on Up Next.
        </p>
      </div>
      <RecommendedShelf
        fallback={
          <p className="text-sm text-muted-foreground">
            Recommendations are off: no AI provider is configured on the server.
          </p>
        }
      />
    </div>
  );
}
