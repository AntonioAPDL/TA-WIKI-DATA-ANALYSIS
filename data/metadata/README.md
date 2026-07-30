# Controlled metadata

The files in this directory are respondent-free contracts used by the workflow.
They define how a frozen source is checked and transformed; they do not contain
survey responses, timestamps, open text, or contact information.

| File | Purpose |
|---|---|
| `variable_map.csv` | Ordered source columns, analysis names, roles, and restricted status. |
| `item-spec.csv` | Item types, domains, primary-analysis flags, skip rules, and release eligibility. |
| `live-header-manifest.csv` | The approved, respondent-free source header contract. |
| `category-codebook.csv` | Canonical values and display order for scalar items. |
| `checkbox-options.csv` | Canonical checkbox options and display order. |
| `derivation-rules.csv` | Controlled internal sensitivity derivations, including their evidence-state conditions. |
| `exploratory-pairs.csv` | The small, internal-only set of predeclared descriptive cross-tabs and their rationale. |
| `publication-labels.csv` | Controlled reader-facing labels and domain order for structured release tables. |
| `transformation-rules.csv` | Named, versioned normalization and recoding rules. |
| `recoding-rules.md` | Plain-language rationale for the transformation rules. |

For Likert items, the shared scale occupies display orders 1--5. Any
item-specific non-scale response must have a distinct order after that scale;
for example, `recommend_wiki` records `Not sure` as order 6.

Changes to any metadata contract can invalidate downstream runs. Record a
decision when a change affects analysis, privacy, release, or interpretation;
use the [decision-record template](../../docs/decision-record-template.md) and
rerun the affected workflow stages.
