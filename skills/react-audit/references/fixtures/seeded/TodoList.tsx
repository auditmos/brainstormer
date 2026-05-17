// rule_id: effects/transforming-data-for-render
import { useEffect, useState } from 'react';

interface Todo {
  id: string;
  text: string;
  done: boolean;
}

function getFilteredTodos(todos: Todo[], filter: string): Todo[] {
  if (filter === 'active') return todos.filter((t) => !t.done);
  if (filter === 'completed') return todos.filter((t) => t.done);
  return todos;
}

interface TodoListProps {
  todos: Todo[];
  filter: string;
}

export function TodoList({ todos, filter }: TodoListProps) {
  const [visibleTodos, setVisibleTodos] = useState<Todo[]>([]);

  useEffect(() => {
    setVisibleTodos(getFilteredTodos(todos, filter));
  }, [todos, filter]);

  return (
    <ul>
      {visibleTodos.map((t) => (
        <li key={t.id}>{t.text}</li>
      ))}
    </ul>
  );
}
