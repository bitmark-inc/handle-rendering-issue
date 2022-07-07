# move an issue to a new repository

(import json :as json)
(import argparse :prefix "")
(import http :as http)

#(use ./base32)


# constants
(def confirmations "gap from current height to protect against reorg" 6)
(def first-block 2)
(def github-graphql-endpoint "https://api.github.com/graphql")

(defn github-issue-url "create a link to an issue"
  [owner repo issue]

  (string/format "https://github.com/%s/%s/issues/%d" owner repo issue))


(defn fail "fail message and exit"
  [fmt & args]

  (printf fmt (splice args))
  (os/exit 1))


(defn workflow-set-output "special string on stdout to set workflow variables"
  [var val]

  (printf "::set-output name=%s::%s" var val))


(defn ql-issue "GraphQL to fetch an issue"
  [owner repo issue]

  (let [q `
query IssueRecord {
  repository(owner: "%s", name: "%s") {
    id
    issue(number: %d) {
      id
      number
      title
      body
      state
      labels(first: 100) {
        nodes {
          name
        }
      }
    }
  }
}`
        s (string/format q owner repo issue)]
    (json/encode @{"query" s})))


(defn ql-repo-id "GraphQL to read the repository id"
  [owner repo]

  (let [q `
query RepoID {
  repository(owner: "%s", name: "%s") {
    id
  }
}`
        s (string/format q owner repo)]
    (json/encode @{"query" s})))


(defn ql-create-issue "GraphQL to create an issue"
  [repo-id title body]

  (let [q `
mutation CreateIssue {
  createIssue(input: {repositoryId: "%s", title: "%s", body: "%s"}) {
    issue {
      id
      title
      number
      body
    }
  }
}`
        s (string/format q repo-id title body)]
    (json/encode @{"query" s})))


(defn ql-close-issue "GraphQL to close an issue with a comment"
  [issue-id body]

  (let [q `
mutation CloseWithComment {
  addComment(input: {subjectId: "%s", body: "%s"}) { clientMutationId }
  updateIssue(input: {id: "%s", state: CLOSED}) { clientMutationId }
}`
        s (string/format q issue-id body issue-id)]
    (json/encode @{"query" s})))


(defn ql-project-id "GraphQL to locate the project"
  [user-org owner project-name]

  (let [q `
query ProjectID {
  %s(login: "%s") {
    projectsV2(query: "%s", first: 1) {
      nodes {
        id
        title
      }
    }
  }
}`
        s (string/format q user-org owner project-name)]
    (json/encode @{"query" s})))


(defn ql-add-to-project "GraphQL to add an issue to a project"
  [issue-id project-id]

  (let [q `
mutation AddIssueToProject {
  addProjectV2ItemById(input: {projectId: "%s", contentId: "%s"}) {
    clientMutationId
    item {
      id
      type
      project {
        fields(first: 100) {
          totalCount
          nodes {
            ... on ProjectV2Field {
              id
              name
            }
          }
        }
      }
    }
  }
}`
        s (string/format q project-id issue-id)]
    (json/encode @{"query" s})))


(defn ql-update-project-item "GraphQL to add an issue to a project"
  [project-id item-id field-id value]

  (let [q`
mutation UpdateProjectItem {
  updateProjectV2ItemFieldValue(
    input: {projectId: "%s", itemId: "%s", fieldId: "%s", value: {text: "%s"}}
  ) {
    clientMutationId
  }
}`
        s (string/format q project-id item-id field-id value)]
    (json/encode @{"query" s})))


(defn exec-ql "execute a GraphQL commad and decode the JSON response"
  [ql headers]

  (let [response (http/post github-graphql-endpoint ql :headers headers)
        status (get response :status)]
    (if (= 200 status)
      {:body (json/decode (get response :body))
       :ok true
       :status status}
      {:body nil
       :ok false
       :status status})))


(defn remove-owner "remove '<owner>/' if present as a prefix"
  [owner repo-path]

  (let [prefix (string owner "/")
        len (length prefix)]
    (if (string/has-prefix? prefix repo-path)
      (string/slice repo-path len)
      repo-path)))

(defn find-by-prefix "find a prefixed line from a block of text"
  [prefix text]

  (let [prefix-length (length prefix)
        line (find
              (fn [a] (string/has-prefix? prefix a)) (string/split "\n" text))]
    (if line
      (let [s (string/slice line prefix-length)]
        (string/trim s))
      "")))


(defn decode-issue "extract data from the issue body"
  [fields issue]

  (let [issue-body (get issue "body")
        is-open (= "OPEN" (get issue "state"))
        extracted (map
                   (fn [f]
                     (let [s (find-by-prefix (string "**" f "**:") issue-body)]
                       [f s]))
                   fields)
        descr (find-by-prefix "Hi," issue-body)]
    {:open is-open
     :extracted (from-pairs extracted)}))


(defn has-label "label record is selected named label is present"
  [name labels]

  (find
   (fn [a] (= name (get a "name"))) labels))



(def argparse-params
  [``Download issue and check if rendering issue
   ``
   "debug" {:kind :flag :short "D"
            :help "debug mode"}
   "verbose" {:kind :multi :short "v"
              :help "print more information"}
   "issue" {:kind :option :short "i"
            :help "issue number"
            :required true}
   "owner" {:kind :option :short "o"
            :help "repository owner"
            :required true}
   "repo" {:kind :option :short "r"
           :help "repository name"
           :required true}
   "label" {:kind :option :short "l"
            :help "label name for actionable issues"
            :required true}
   "fields" {:kind :option :short "f"
             :help "comma separated list of fields for extracting data"
             :required true}
   "token" {:kind :option :short "t"
            :help "token to access owne/repo"
            :required true}
   "out-owner" {:kind :option :short "O"
                :help "output repository owner"
                :required true}
   "out-owner-type" {:kind :option :short "U"
                     :help "output repository owner is user rather than organisation"
                     :required false}
   "out-repo" {:kind :option :short "R"
               :help "output repository name"
               :required true}
   "out-project" {:kind :option :short "P"
               :help "output project name"
               :required true}
   "out-token" {:kind :option :short "T"
                :help "token to access out-owner/out-repo"
                :required true}
   :default {:kind :accumulate}])


(defn main "main program"
  [p &]

  (def opts (argparse (splice argparse-params)))

  (unless opts
    (os/exit 1))

  (def issue (scan-number (get opts "issue")))
  (when (nil? issue)
    (fail "issssue value: `%s` is not a number\n" (get opts "issue")))

  (def owner (get opts "owner"))
  (def repo (remove-owner owner (get opts "repo")))
  (def report-label (get opts "label"))
  (def fields
    (map string/trim (string/split "," (get opts "fields"))))

  (def token (get opts "token"))

  (def out-owner (get opts "out-owner"))
  (def out-user-org (if (= "user" (get opts "out-owner-type")) "user" "organization"))
  (def out-repo (remove-owner out-owner (get opts "out-repo")))
  (def out-project (get opts "out-project"))

  (def out-token (get opts "out-token"))

  (def debug (get opts "debug"))
  (def verbose (get opts "verbose" 0))

  (when debug
    (pp opts)
    (printf "fields: %P" fields)
    (printf "ql-issue: %P" (ql-issue owner repo issue)))

  (def headers {"Content-Type" "application/json"
                "Accept" "application/vnd.github.v3+json"
                "Authorization" (string "Bearer " token)})
  (def out-headers {"Content-Type" "application/json"
                "Accept" "application/vnd.github.v3+json"
                "Authorization" (string "Bearer " out-token)})


  (def issue-result (exec-ql (ql-issue owner repo issue) headers))
  (when debug
    (printf "issue-result: %P" issue-result))
  (unless (get issue-result :ok)
    (fail "missing issue on: %s / %s / %d" owner repo issue))

  (def out-repo-result (exec-ql (ql-repo-id out-owner out-repo) out-headers))
  (when debug
    (printf "out-repo-result: %P" out-repo-result))
  (unless (get out-repo-result :ok)
    (fail "missing repo: %s / %s" out-owner out-repo))

  (def project-result (exec-ql (ql-project-id out-user-org out-owner out-project) out-headers))
  (when debug
    (printf "project-result: %P" project-result))
  (unless (get project-result :ok)
    (fail "cannot create identify the project %s / %s" out-owner out-project))

  (def project-id (get-in project-result [:body "data" out-user-org "projectsV2" "nodes" 0 "id"]))
  (when debug
    (printf "project-id: %P" project-id))
  (when (nil? project-id)
    (fail "cannot create identify the project %s / %s" out-owner out-project))


  (def out-repo-id (get-in out-repo-result [:body "data" "repository" "id"]))

  (def repo-id (get-in issue-result [:body "data" "repository" "id"]))
  (def issue-data (get-in issue-result [:body "data" "repository" "issue"]))
  (def issue-id (get issue-data "id"))
  (def issue-labels (get-in issue-data ["labels" "nodes"]))



  (when debug
    (printf "processed data: %P"
            {:in-repo repo-id
             :out-repo out-repo-id
             :data issue-data}))

  (def decoded-issue (decode-issue fields issue-data))
  (when debug
    (printf "decoded: %P" decoded-issue))

  (def hl (has-label report-label issue-labels))
  (when debug
    (printf "has label: '%s' is: %P" report-label hl))

  # exit if cannot decode the incoming issue
  (unless (and (get decoded-issue :open) hl)
    (os/exit 0))

  (let [new-issue-title (string (get-in decoded-issue [:extracted "Artwork"] "Unnamed")
                                  " by "
                                  (get-in decoded-issue [:extracted "Creator"] "Unknown"))
        new-issue-body (string
                        ;(map (fn [a] (def [k v] a)
                                (string k ": " v "\n"))
                              (pairs (get decoded-issue :extracted))))]
    (when debug
      (printf "new title: %P" new-issue-title)
      (printf "new body: %P" new-issue-body))

    (def create-result (exec-ql (ql-create-issue out-repo-id new-issue-title new-issue-body) out-headers))
    (when debug
      (printf "create-result: %P" create-result))

    (unless (get create-result :ok)
      (fail "cannot create the new issue"))

    (let [number (get-in create-result [:body "data" "createIssue" "issue" "number"])
          new-issue-id (get-in create-result [:body "data" "createIssue" "issue" "id"])
          new-url (github-issue-url out-owner out-repo number)
          old-url (github-issue-url owner repo issue)
          issue-comment (string/format "This issue has been moved to a public board: %s\n" new-url)]

      (when verbose
        (printf "new issue created: %s" new-url)
        (printf "closing old issue: %s" old-url))

      (def close-result (exec-ql (ql-close-issue issue-id issue-comment) headers))
      (when debug
        (printf "close-result: %P" close-result))

      (workflow-set-output "issueId" new-issue-id)
      (workflow-set-output "issueNumber" (string number))
      (workflow-set-output "owner" out-owner)
      (workflow-set-output "repo" out-repo)

      (def add-to-project-result (exec-ql (ql-add-to-project new-issue-id project-id) out-headers))
      (when debug
        (printf "add-to-project-result: %P" add-to-project-result))
      (unless (get add-to-project-result :ok)
        (fail "cannot add the new issue %s / %s / %d  to: %s / %s"
              out-owner out-repo number
              out-owner out-project))

      (def item-id (get-in add-to-project-result [:body "data" "addProjectV2ItemById" "item" "id"]))
       (def field-list-in (get-in add-to-project-result [:body "data" "addProjectV2ItemById" "item" "project" "fields" "nodes"]))
      (def field-list (filter truthy?
                        (map (fn [f]
                               (let [value (get-in decoded-issue [:extracted (get f "name")])
                                     ok (and (string? value) (not= value ""))]
                                 (if ok
                                   {:name (get f "name")
                               :id (get f "id")
                                    :value value}
                                   nil)))
                             field-list-in)))
      (when debug
        (printf "project-id: %P" project-id)
        (printf "item-id: %P" item-id)
        (printf "fields in: %P" field-list-in)
        (printf "field list: %P" field-list))

      (workflow-set-output "project" out-project)
      (workflow-set-output "projectID" project-id)
      (workflow-set-output "projectItemID" item-id)

      (map
       (fn [f]
         (let [field-id (get f :id)
               name (get f :name)
               value (get f :value)
               q (ql-update-project-item project-id item-id field-id value)]
           (when debug
             (printf "field Q: %P" q))

           (def update-item-result (exec-ql q out-headers))
           (when debug
             (printf "update-item-result: %P" update-item-result))
           (unless (get update-item-result :ok)
             (fail "cannot update item: %s / %s  field:  %s := %s"
                   out-owner out-project name value))))
       field-list)

      )
    )

  (os/exit 0))
