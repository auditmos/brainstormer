// rule_id: effects/adjusting-state-on-prop-change
import { useEffect, useState } from 'react';

interface Item {
  id: string;
  label: string;
}

interface SelectableListProps {
  items: Item[];
}

export function SelectableList({ items }: SelectableListProps) {
  const [selection, setSelection] = useState<Item | null>(null);

  useEffect(() => {
    setSelection(null);
  }, [items]);

  return (
    <ul>
      {items.map((it) => (
        <li
          key={it.id}
          aria-selected={selection?.id === it.id}
          onClick={() => setSelection(it)}
        >
          {it.label}
        </li>
      ))}
    </ul>
  );
}
