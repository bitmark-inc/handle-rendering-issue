(declare-project
 :name "handle-rendering-issue"
 :description "move an issue to a new board"
 :dependencies ["json"
                "argparse"
                "https://github.com/joy-framework/http"])
(declare-source
 :source @["src"])

(declare-executable
 :name "handle-rendering-issue"
 :entry "src/main.janet")
