# AI Coding Agent Instructions

## Overview
This repository contains multiple sub-projects, including LaTeX documents, PlantUML diagrams, and Structurizr workspace files. Each sub-project serves a distinct purpose, and understanding their structure is key to contributing effectively.

### Key Components
1. **LaTeX Documents**
   - Located in the `latex/` directory.
   - Contains the main LaTeX files (`main.tex`, `preamble.tex`) and chapters (`chapters/`).
   - Build artifacts are stored in the `build/` directory.
   - Images and other assets are in `images/`.

2. **PlantUML Diagrams**
   - Found in the `plantuml/` directory.
   - Includes `.puml` files for generating UML diagrams.

3. **Structurizr Workspace**
   - Located in the `Structurizr/` directory.
   - Contains workspace definitions (`workspace.dsl`, `workspace.json`) for Structurizr diagrams.

## Developer Workflows

### Building LaTeX Documents
- Use `latexmk` to build the LaTeX files:
  ```bash
  latexmk -pdf main.tex
  ```
- Clean build artifacts:
  ```bash
  latexmk -c
  ```

### Generating PlantUML Diagrams
- Use the `plantuml` command-line tool:
  ```bash
  plantuml deploy.puml
  ```

### Structurizr Diagrams
- Edit the `workspace.dsl` file to define the architecture.
- Use Structurizr CLI to generate diagrams:
  ```bash
  structurizr-cli push -workspace workspace.dsl
  ```

## Project-Specific Conventions

### LaTeX
- Use `preamble.tex` for shared LaTeX configurations.
- Store chapter-specific content in `chapters/`.

### PlantUML
- Follow the naming convention `<diagram_name>.puml`.
- Keep diagrams modular and focused on a single concept.

### Structurizr
- Use `workspace.dsl` as the source of truth for architecture definitions.
- Keep JSON files (`workspace.json`) in sync with the DSL file.

## Integration Points
- **Docker**: The repository includes `Dockerfile` and `docker-compose.yml` files for containerized workflows.
- **External Tools**: Requires `latexmk`, `plantuml`, and `structurizr-cli` for respective workflows.

## Examples

### Adding a New Chapter (LaTeX)
1. Create a new `.tex` file in `chapters/`.
2. Include it in `main.tex`:
   ```latex
   \include{chapters/new_chapter}
   ```

### Adding a New Diagram (PlantUML)
1. Create a new `.puml` file in `plantuml/`.
2. Generate the diagram:
   ```bash
   plantuml new_diagram.puml
   ```

### Updating Structurizr Workspace
1. Modify `workspace.dsl`.
2. Push changes:
   ```bash
   structurizr-cli push -workspace workspace.dsl
   ```