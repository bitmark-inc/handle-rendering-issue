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
  repository(owner:"%s" name:"%s") {
    id
    issue(number:%d) {
      id
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
  repository(owner:"%s" name:"%s") {
    id
  }
}`
        s (string/format q owner repo)]
    (json/encode @{"query" s})))


(defn ql-create-issue "GraphQL to create an issue"
  [repo_id title body]

  (let [q `
mutation CreateIssue {
  createIssue(input: {repositoryId:"%s" title:"%s" body:"%s"}) {
    issue {
      id
      title
      number
      body
    }
  }
}`
        s (string/format q repo_id title body)]
    (json/encode @{"query" s})))


(defn ql-close-issue "GraphQL to close an issue with a comment"
  [issue_id body]

  (let [q `
mutation CloseWithComment {
  addComment(input: {subjectId: "%s", body: "%s"}) { clientMutationId }
  closeIssue(input: {issueId: "%s"}) { clientMutationId }
}`
        s (string/format q issue_id body issue_id)]
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
  [issue]

  (let [issue-body (get issue "body")
        is-open (= "OPEN" (get issue "state"))
        url (find-by-prefix "**TokenURL**:" issue-body)
        descr (find-by-prefix "Hi," issue-body)]
    {:open is-open
     :url url
     :descr descr}))


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
   "token" {:kind :option :short "t"
            :help "token to access owne/repo"
            :required true}
   "out-owner" {:kind :option :short "O"
                :help "output repository owner"
                :required true}
   "out-repo" {:kind :option :short "R"
               :help "output repository name"
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
  (def token (get opts "token"))

  (def out-owner (get opts "out-owner"))
  (def out-repo (remove-owner out-owner (get opts "out-repo")))
  (def out-token (get opts "out-token"))


  (def debug (get opts "debug"))
  (def verbose (get opts "verbose" 0))

  (when debug
    (pp opts)
    (printf "Q: %v" (ql-issue owner repo issue)))

  (def headers {"Content-Type" "application/json"
                "Accept" "application/vnd.github.v3+json"
                "Authorization" token})
  (def out-headers {"Content-Type" "application/json"
                "Accept" "application/vnd.github.v3+json"
                "Authorization" out-token})


  (def issue-result (exec-ql (ql-issue owner repo issue) headers))
  (when debug
    (printf "issue-result: %P" issue-result))


  (def out-repo-result (exec-ql (ql-repo-id out-owner out-repo) out-headers))
  (when debug
    (printf "out-repo-result: %P" out-repo-result))

  (when (and (get issue-result :ok) (get out-repo-result :ok))

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

    (def decoded-issue (decode-issue issue-data))

    (def hl (has-label report-label issue-labels))
    (when debug
       (printf "has label: '%s' is: %P" report-label hl))


    (when (and (get decoded-issue :open) hl)
      (let [issue-title (string/format "formerly support issue: %d" issue)
            issue-descr (string (get decoded-issue :descr) "\nrendering problem with: " (get decoded-issue :url))]

        (when verbose
          (printf "NFT token: %s" (get decoded-issue :url)))

        (def create-result (exec-ql (ql-create-issue out-repo-id issue-title issue-descr) out-headers))
        (when debug
          (printf "create-result: %P" create-result))

        (when (get create-result :ok)

          (let [number (get-in create-result [:body "data" "createIssue" "issue" "number"])
                new-url (github-issue-url out-owner out-repo number)
                old-url (github-issue-url owner repo issue)
                issue-comment (string/format "This issue has been moved to a public board: %s\n" new-url)]

            (when verbose
              (printf "new issue created: %s" new-url)
              (printf "closing old issue: %s" old-url))

            (def close-result (exec-ql (ql-close-issue issue-id issue-comment) headers))
            (when debug
              (printf "close-result: %P" close-result))

            (workflow-set-output "issue" number)
            (workflow-set-output "owner" out-owner)
            (workflow-set-output "repo" out-repo))

          )
        )
      )
    )
  (os/exit 0))
