# WeInc Website Builder Action

[![Release](https://img.shields.io/github/v/release/umairalisadaqat/weinc-action)](https://github.com/umairalisadaqat/weinc-action/releases)

Manage [WeInc](https://we.inc) websites from your CI pipelines. This action wraps the
[WeInc Agency API](https://my.we.inc/api/v1/docs) so you can list, create, and update
projects and clients, pull site analytics, and inspect templates, plans, and webhooks —
straight from a GitHub workflow.

## Usage

```yaml
name: WeInc
on: [workflow_dispatch]

jobs:
  weinc:
    runs-on: ubuntu-latest
    steps:
      - name: Create a client site
        id: site
        uses: umairalisadaqat/weinc-action@v1
        with:
          api_key: ${{ secrets.WEINC_API_KEY }}
          command: create-project
          client_email: client@example.com
          name: "Acme Landing Page"
          description_text: "Marketing site for Acme"

      - name: Show the new project id
        run: echo "Created project ${{ steps.site.outputs.id }}"

      - name: Pull last 30 days of analytics
        uses: umairalisadaqat/weinc-action@v1
        with:
          api_key: ${{ secrets.WEINC_API_KEY }}
          command: get-analytics
          days: 30
```

## Inputs

| Input | Required | Description |
|---|---|---|
| `api_key` | yes | WeInc organization API key (`wk_...`), created in your agency dashboard at [my.we.inc](https://my.we.inc). Store it as a repository secret. |
| `command` | yes | One of `list-projects`, `get-project`, `create-project`, `update-project`, `delete-project`, `list-clients`, `get-client`, `create-client`, `list-templates`, `list-plans`, `get-analytics`, `list-webhooks` |
| `project_id` | for project commands | Target project ID |
| `client_id` | optional | Client ID (filter for `list-projects`, target for `get-client`) |
| `client_email` | for `create-project` / `create-client` | Client email address |
| `name` | for create commands | Project or client name |
| `description_text` | optional | Project description |
| `template_id` | optional | Org template to clone files from when creating a project |
| `days` | optional | Look-back window for `get-analytics` |
| `api_url` | optional | API base URL (default `https://my.we.inc/api/v1`) |

## Outputs

| Output | Description |
|---|---|
| `json` | Raw JSON response from the WeInc API |
| `id` | ID of the created or fetched resource, when applicable |

## Rate limits

The WeInc API allows 100 requests per minute per API key.

## Related

- [weinc-cli](https://github.com/umairalisadaqat/weinc-cli) — build WeInc sites from your terminal
- [we.inc](https://we.inc) — the AI website builder

## License

MIT. See [LICENSE](LICENSE).
