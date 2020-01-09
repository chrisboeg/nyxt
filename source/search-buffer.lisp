;;; search-buffer.lisp --- functions to enable searching within a buffer

(in-package :next)

(define-parenscript query-buffer (query)
  (defvar *matches* (array))
  
  (defun qsa (context selector)
    "Alias of document.querySelectorAll"
    (ps:chain context (query-selector-all selector)))
  
  (defun match-object-create (body)
    (ps:create "type" "match" "identifier" 0 "body" body))
  
  (defun get-substring (index string)
    "Return the substring and preceding/trailing text for a given index."
    (let ((start-index (if (> (- index 20) 0) (- index 20) 0))
          (end-index (+ index 20)))
      (ps:chain string (substring start-index end-index))))
  
  (defun get-substring-matches (search-string string case-sensitive-p)
    "Return all of substrings that match the search-string."
    (let ((search-string-length (ps:chain search-string length))
          (search-string (if case-sensitive-p search-string (ps:chain search-string (to-lower-case))))
          (string (if case-sensitive-p string (ps:chain string (to-lower-case)))))
      (loop with i = (ps:chain string (index-of search-string 0))
            until (equal i -1)
            collect (match-object-create (get-substring i string))
            do (setf i (ps:chain string (index-of search-string (+ i 1)))))))
  
  (defun matches-from-element (element query)
    (when (= (ps:chain (typeof (ps:@ element node-value))) "string")
      (ps:chain *matches* push (apply *matches*
                                      (get-substring-matches query (ps:@ element node-value) t)))))
  
  (defun walk-document (node process-node)
    (when (and node (not (ps:chain node first-child)))
      (funcall process-node node (ps:lisp query)))
    (setf node (ps:chain node first-child))
    (loop while node
          do (walk-document node process-node)
          do (setf node (ps:chain node next-sibling))))
  
  (let ((*matches* (array)))
    (walk-document (ps:chain document body) matches-from-element)
    (ps:chain -j-s-o-n (stringify *matches*))))

(defclass match ()
  ((identifier :accessor identifier :initarg :identifier)
   (body :accessor body :initarg :body)))

(defmethod object-string ((match match))
  (format nil "...~a..." (body match)))

(defun matches-from-json (matches-json)
  (loop for element in (cl-json:decode-json-from-string matches-json)
        collect (make-instance 'match
                               :identifier (cdr (assoc :identifier element))
                               :body (cdr (assoc :body element)))))

(defun match-completion-function (input)
  "This function will update the completions asynchronously via
query-buffer. TODO: capture the current-buffer and current-minibuffer
in a closure."
  (when (> (length input) 2)
    (query-buffer
     :query input
     :callback (lambda (result)
                 (set-completions (current-minibuffer)
                                  (matches-from-json result)))))
  ;; return an empty list, the completions will be updated
  ;; asynchronously by the callback from query-buffer
  (list ""))

(define-command search-buffer ()
  "Add search boxes for a given search string."
  (with-result (input (read-from-minibuffer
                       (make-minibuffer
                        :input-prompt "Search for (3+ characters)"
                        :completion-function 'match-completion-function
                        :history (minibuffer-search-history *interface*))))
    (print input)))

(define-command remove-search-hints ()
  "Remove all search hints.")

(define-command next-search-hint ()
  "Go to next search hint.")

(define-command previous-search-hint ()
  "Go to previous search hint.")

(define-deprecated-command add-search-hints ()
  "Deprecated by `search-buffer'."
  (search-buffer))
