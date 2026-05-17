// rule_id: effects/caching-expensive-computation
import { useEffect, useState } from 'react';

interface Row {
  id: string;
  value: number;
  group: string;
}

function buildAggregatedReport(rows: Row[], filter: string): Row[] {
  // expensive: sort, then filter, then dedupe by group
  return rows
    .slice()
    .sort((a, b) => a.value - b.value)
    .filter((r) => (filter === 'all' ? true : r.group === filter));
}

interface ReportTableProps {
  rows: Row[];
  filter: string;
}

export function ReportTable({ rows, filter }: ReportTableProps) {
  const [aggregated, setAggregated] = useState<Row[]>([]);

  useEffect(() => {
    // cached because the computation is expensive
    setAggregated(buildAggregatedReport(rows, filter));
  }, [rows, filter]);

  return (
    <table>
      <tbody>
        {aggregated.map((r) => (
          <tr key={r.id}>
            <td>{r.group}</td>
            <td>{r.value}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
