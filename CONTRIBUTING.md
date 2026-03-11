# Contributing

> This project follows the [Zairakai Global Contributing Guide][handbook-contributing].  
> Please read it before contributing. The sections below document project-specific workflow.

---

## Development Workflow

| Step | Command / Action | Description |
| :--- | :--- | :--- |
| **1. Install** | `npm install && bash scripts/install-hooks.sh` | Install dependencies and set up git hooks. |
| **2. Branch** | `git checkout -b feature/#TICKET-name` | Create a feature branch from `develop`. |
| **3. Code** | *(your IDE)* | Implement your changes following quality standards. |
| **4. Quality** | `make quality` | Run the full quality gate. |
| **5. Test** | `make test-all` | Ensure all tests (Vitest + BATS) are passing. |
| **6. Commit** | `git commit -m "type(scope): #TICKET subject"` | Use [Conventional Commits][git-rules] format. |
| **7. Push** | `git push origin feature/#TICKET-name` | Push and open a Merge Request to `main`. |

---

## Types of Contributions

| Type | Guidelines |
| :--- | :--- |
| **🐛 Bug Reports** | Use the issue template. Include minimal reproduction steps, expected vs actual behavior, and environment details. |
| **✨ Feature Requests** | Describe the use case and problem solved. Provide example usage and check for existing issues. |
| **🔧 Config Updates** | For ESLint/Prettier/Stylelint in `config/`. Maintain backward compatibility and follow community standards. |
| **🛠️ Make Targets** | For `.mk` files in `tools/make/`. Follow naming patterns and include help comments. |
| **🐚 Shell Scripts** | For `scripts/`. Ensure 100% ShellCheck compliance and use `config.sh` for logging. |

---

## Quality Targets

| Command | Tool | Description |
| :--- | :--- | :--- |
| `make quality` | All | Full static analysis and formatting gate. |
| `make eslint` | ESLint | Run JS/TS static analysis. |
| `make prettier` | Prettier | Check code formatting. |
| `make stylelint` | Stylelint | Run SCSS/CSS static analysis. |
| `make typecheck` | TSC | Run TypeScript type checking. |
| `make markdownlint` | Markdownlint | Validate Markdown documentation. |
| `make test` | Vitest | Run unit tests with coverage. |
| `make bats` | BATS | Run shell script integration tests. |

---

[handbook-contributing]: https://gitlab.com/zairakai/handbook/-/blob/main/CONTRIBUTING.md
[git-rules]: https://gitlab.com/zairakai/handbook/-/blob/main/policies/git-rules.md
