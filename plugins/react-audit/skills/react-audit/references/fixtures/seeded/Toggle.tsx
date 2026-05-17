// rule_id: effects/notifying-parent-state-changes
import { useEffect, useState } from 'react';

interface ToggleProps {
  onChange: (on: boolean) => void;
}

export function Toggle({ onChange }: ToggleProps) {
  const [isOn, setIsOn] = useState(false);

  useEffect(() => {
    onChange(isOn);
  }, [isOn, onChange]);

  return (
    <button onClick={() => setIsOn((v) => !v)}>
      {isOn ? 'On' : 'Off'}
    </button>
  );
}
