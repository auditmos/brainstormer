// rule_id: effects/sending-post-request
import { useEffect, useState } from 'react';

export function RegistrationForm() {
  const [first, setFirst] = useState('');
  const [last, setLast] = useState('');
  const [submitted, setSubmitted] = useState(false);

  useEffect(() => {
    if (submitted) {
      fetch('/api/register', {
        method: 'POST',
        body: JSON.stringify({ first, last }),
      });
    }
  }, [submitted]);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitted(true);
  }

  return (
    <form onSubmit={handleSubmit}>
      <input value={first} onChange={(e) => setFirst(e.target.value)} />
      <input value={last} onChange={(e) => setLast(e.target.value)} />
      <button type="submit">Register</button>
    </form>
  );
}
