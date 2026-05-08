import { useState } from 'react';

interface UserCardProps {
  initialFirstName: string;
  initialLastName: string;
}

export function UserCard({ initialFirstName, initialLastName }: UserCardProps) {
  const [firstName, setFirstName] = useState(initialFirstName);
  const [lastName, setLastName] = useState(initialLastName);
  const fullName = firstName + ' ' + lastName;

  return (
    <div>
      <input value={firstName} onChange={(e) => setFirstName(e.target.value)} />
      <input value={lastName} onChange={(e) => setLastName(e.target.value)} />
      <p>{fullName}</p>
    </div>
  );
}
