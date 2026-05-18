// rule_id: rerenders/inline-object-prop
// cold-path occurrence — generic settings card location, file name does
// not match any hot-path glob in SKILL.md §Code Scanner / Severity
// assignment. The default Optimization severity stays in place.
import { memo, useState } from 'react';

type LabelProps = { fontWeight: number; color: string };
const SettingLabel = memo(function SettingLabel({ style }: { style: LabelProps }) {
  return <span style={style}>label</span>;
});

export function SettingsCard() {
  const [expanded, setExpanded] = useState(false);
  return (
    <section onClick={() => setExpanded((v) => !v)}>
      <SettingLabel style={{ fontWeight: 600, color: '#333' }} />
    </section>
  );
}
