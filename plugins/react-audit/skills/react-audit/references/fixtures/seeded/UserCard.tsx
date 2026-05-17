import { useEffect, useState } from 'react';
// rule_id: effects/computing-derived-state
interface UserCardProps {
  initialFirstName: string;
  initialLastName: string;
}

export function UserCard({ initialFirstName, initialLastName }: UserCardProps) {
  const [firstName, setFirstName] = useState(initialFirstName);
  const [lastName, setLastName] = useState(initialLastName);
  const [fullName, setFullName] = useState('');

  useEffect(() => {
    setFullName(firstName + ' ' + lastName);
  }, [firstName, lastName]);

  return (
    <div>
      <input value={firstName} onChange={(e) => setFirstName(e.target.value)} />
      <input value={lastName} onChange={(e) => setLastName(e.target.value)} />
      <p>{fullName}</p>
    </div>
  );
}
