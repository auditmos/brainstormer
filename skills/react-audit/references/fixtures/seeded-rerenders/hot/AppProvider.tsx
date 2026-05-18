// rule_id: rerenders/inline-object-prop
// hot-path occurrence — file name matches the `*Provider.tsx` glob in
// SKILL.md §Code Scanner / Severity assignment, so the heuristic upgrades
// the default Optimization severity to Blocker.
import { memo, useState } from 'react';

type ThemeProps = { palette: string; spacing: number };
const ThemedShell = memo(function ThemedShell({ theme }: { theme: ThemeProps }) {
  return <div data-palette={theme.palette}>shell</div>;
});

export function AppProvider() {
  const [active, setActive] = useState(false);
  return (
    <button onClick={() => setActive((v) => !v)}>
      <ThemedShell theme={{ palette: 'dark', spacing: 8 }} />
    </button>
  );
}
