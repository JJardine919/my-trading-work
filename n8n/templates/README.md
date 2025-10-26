# n8n Workflow Templates

This directory is for storing your custom workflow templates.

## Usage

Place your n8n workflow JSON files here for:
- Backup and version control
- Sharing workflows across instances
- Maintaining workflow templates

## Template Structure

Each workflow should be a JSON file exported from n8n with a descriptive name:

```
templates/
├── my-custom-analysis.json
├── portfolio-rebalance.json
└── alert-system.json
```

## Creating Templates

1. Design workflow in n8n UI
2. Test thoroughly
3. Export: Workflow menu → Download
4. Save to this directory
5. Commit to git for version control

## Best Practices

- Use descriptive filenames
- Document workflow purpose in filename or README
- Remove sensitive credentials before committing
- Use environment variables for configuration
- Tag workflows appropriately
