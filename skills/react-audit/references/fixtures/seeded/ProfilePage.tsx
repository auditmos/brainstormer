// rule_id: effects/resetting-all-state-on-prop-change
import { useEffect, useState } from 'react';

interface ProfilePageProps {
  userId: string;
}

export function ProfilePage({ userId }: ProfilePageProps) {
  const [comment, setComment] = useState('');
  const [isPublished, setIsPublished] = useState(false);
  const [isExpanded, setIsExpanded] = useState(false);

  useEffect(() => {
    setComment('');
    setIsPublished(false);
    setIsExpanded(false);
  }, [userId]);

  return (
    <div>
      <h2>Profile {userId}</h2>
      <textarea value={comment} onChange={(e) => setComment(e.target.value)} />
      <button onClick={() => setIsExpanded((v) => !v)}>
        {isExpanded ? 'Collapse' : 'Expand'}
      </button>
      <button onClick={() => setIsPublished(true)} disabled={isPublished}>
        Publish
      </button>
    </div>
  );
}
