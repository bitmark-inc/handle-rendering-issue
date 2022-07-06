# Handle rendering issues

# Quick start

```yaml
- uses: bitmark-inc/handle-rendering-issue@v1
  id: my_step_id
  with:
    issue: ${{ github.event.issue.number }}
    owner: ${{ github.repository_owner }}
    repo: ${{ github.repository }}
    label: "action one"
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    outOwner: ${{ github.repository_owner }}
    outRepo: new-output-repo-name
    OUT_GITHUB_TOKEN: ${{ secrets.OUT_GITHUB_TOKEN }}
- name: Print outputs
  run: |
    echo ${{ steps.my_step_id.outputs.owner }}
    echo ${{ steps.my_step_id.outputs.repo }}
    echo ${{ steps.my_step_id.outputs.issue }}
```


# Inputs

| Name                | Required  | Description  |
| ------------------- | --------- | ------------ |
| issue               | true      | incoming issue number |
| owner               | true      | incoming repository owner |
| repo                | true      | incoming repo name |
| label               | true      | only process issues created with this label |
| GITHUB\_TOKEN       | true      | incoming repo access token |
| outOwner            | true      | outgoing repository owner |
| outRepo             | true      | outgoing repo name |
| OUT\_GITHUB\_TOKEN  | true      | outgoing repo access token |

# Outputs

| Name   | Description  |
| ------ | ------------ |
| issue  | newly created issue number in outgoing repo |
| owner  | owner of outgoing repo |
| repo   | name of outgoing repo |
