# Handle rendering issues

Create a new issue on anew board with only part of the data from incoming issue.
Add the issue to a project board filling in any matching fields.

# Quick start

```yaml
- uses: bitmark-inc/handle-rendering-issue@v1
  id: my_step_id
  with:
    issue: ${{ github.event.issue.number }}
    owner: ${{ github.repository_owner }}
    repo: ${{ github.repository }}
    label: "action one"
    fields: "Artwork,Creator,Collection,TokenURL"
    token: ${{ secrets.GITHUB_TOKEN }}
    outOwner: ${{ github.repository_owner }}
    outRepo: new-output-repo-name
    outProject: "output project name"
    outToken: ${{ secrets.OUT_GITHUB_TOKEN }}
- name: Print outputs
  run: |
    echo ${{ steps.my_step_id.outputs.owner }}
    echo ${{ steps.my_step_id.outputs.repo }}
    echo ${{ steps.my_step_id.outputs.issueNumber }}
    echo ${{ steps.my_step_id.outputs.issueID }}
    echo ${{ steps.my_step_id.outputs.project }}
    echo ${{ steps.my_step_id.outputs.projectID }}
    echo ${{ steps.my_step_id.outputs.projectItemID }}
```


# Inputs

| Name          | Required  | Description  |
| ------------- | --------- | ------------ |
| issue         | true      | incoming issue number |
| owner         | true      | incoming repository owner |
| repo          | true      | incoming repo name |
| label         | true      | only process issues created with this label |
| fields        | true      | comma separated list e.g., `Artwork,Creator` |
| closeComment  | false     | message string with a single %s where the URL should be substituted |
| token         | true      | incoming repo access token |
| outOwner      | true      | outgoing repository/project owner |
| outOwnerType  | false     | outgoing project owner type: `[user|orgainization]` default: `organization` |
| outRepo       | true      | outgoing repo name |
| outProject    | true      | outgoing project name |
| outToken      | true      | outgoing project/repo access token |

# Outputs

| Name          | Description  |
| ------------- | ------------ |
| issueID       | newly created issue ID in outgoing repo |
| issueNumber   | newly created issue number in outgoing repo |
| owner         | owner of outgoing repo |
| repo          | name of outgoing repo |
| project       | name of project |
| projectID     | ID of project |
| projectItemID | ID of project item just added |
