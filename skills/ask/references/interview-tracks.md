# Interview Tracks

Select and adapt tracks based on context. You do not need to cover every track — use judgment.

## Track 1: Problem & Users

- Who exactly has this problem? How many of them are there?
- How do they solve it today? What's painful about the current approach?
- What does success look like for the end user?
- How will you measure whether this is working?
- What happens if you don't build this?

## Track 2: Business Model & Constraints

- What's the revenue model? (Or: what justifies the investment?)
- What's the budget and timeline?
- How large is the team that will build and maintain this?
- Are there existing commitments, contracts, or deadlines that constrain the solution?
- Who are the stakeholders and what are their competing priorities?

## Track 3: Scale & Operations

- How many users do you expect at launch? In 12 months?
- What's the data sensitivity level? (Public, internal, PII, regulated)
- What are the uptime and availability requirements?
- Geographic distribution — single region or multi-region?
- Who handles support, and what does the support model look like?

## Domain-Aware Probing

If the conversation reveals domain-specific concerns, probe deeper:

**HealthTech / Medical / Patient Data**
- HIPAA compliance requirements and BAA needs
- Audit trail and access logging requirements
- Data retention and deletion policies
- PHI handling and de-identification needs

**Finance / Payments / Billing**
- PCI-DSS scope and compliance level
- SOC 2 requirements
- Financial regulation considerations (state/federal)
- Transaction audit and reconciliation needs

**Multi-Tenant SaaS**
- Data isolation strategy (logical vs. physical)
- Tenant boundary enforcement
- Per-tenant customization requirements
- Tenant onboarding and offboarding processes
