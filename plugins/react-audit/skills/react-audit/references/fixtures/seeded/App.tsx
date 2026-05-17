// rule_id: effects/initializing-application
import { useEffect } from 'react';

function loadDataFromLocalStorage(): void {}
function initAnalytics(): void {}

export function App() {
  useEffect(() => {
    loadDataFromLocalStorage();
    initAnalytics();
  }, []);

  return <main>Routes go here</main>;
}
