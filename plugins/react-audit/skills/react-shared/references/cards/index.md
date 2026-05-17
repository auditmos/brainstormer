# Rule Card Index

> Cheap pre-load lookup for the React audit skill suite. One file per rule
> under `skills/react-shared/references/cards/<category>/<slug>.md`.
> Frontmatter schema: `id`, `category`, `detect`, `source` (mandatory);
> `bad` / `good` ship as inline body sections.
>
> Categories (per PRD #1): effects, rerenders, shadcn, a11y, tanstack,
> server-client, typescript, styling.

## effects

- [effects/computing-derived-state](effects/computing-derived-state.md) — `useEffect` derives state that is already computable during render
- [effects/fetching-data](effects/fetching-data.md) — `useEffect` + `fetch` for data loading, no race-condition guard, no framework data primitive
- [effects/chains-of-computations](effects/chains-of-computations.md) — cascade of `useEffect`s each watching state and triggering the next, causing N+1 rerenders
- [effects/sending-post-request](effects/sending-post-request.md) — POST fired from `useEffect` in response to user action instead of from the event handler
- [effects/initializing-application](effects/initializing-application.md) — app-wide initialization placed in a component `useEffect` instead of module scope, runs twice in Strict Mode
- [effects/notifying-parent-state-changes](effects/notifying-parent-state-changes.md) — `useEffect` calls `onChange` prop when internal state changes, instead of calling it in the handler that set the state
- [effects/transforming-data-for-render](effects/transforming-data-for-render.md) — `useEffect` filters/sorts/maps a list into state instead of computing it during render
- [effects/caching-expensive-computation](effects/caching-expensive-computation.md) — `useEffect` + `useState` used as a cache for an expensive computation instead of `useMemo`
- [effects/resetting-all-state-on-prop-change](effects/resetting-all-state-on-prop-change.md) — `useEffect` resets every piece of state when a key-like prop changes, instead of remounting via `key`
- [effects/adjusting-state-on-prop-change](effects/adjusting-state-on-prop-change.md) — `useEffect` adjusts a single piece of state on prop change, instead of adjusting during render with a previous-prop comparison
- [effects/sharing-logic-between-handlers](effects/sharing-logic-between-handlers.md) — logic deduplicated into `useEffect` even though both triggers are event handlers — belongs in a shared helper called from each handler
