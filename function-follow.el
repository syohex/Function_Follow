(defvar ff/java-definition-keywords     '("public" "private"))
(defvar ff/lisp-definition-keywords     '("defun"))
(defvar ff/python-definition-keywords   '("def"))
(defvar ff/perl-definition-keywords     '("sub"))

(defvar ff/depth nil)

(defun ff/function-follow (point-mark mark-region)
  "Find the definition of the selected/highlighted function.
It first checks the current file, then any open buffers
with the same file extension, and finally any files in
the current directory with the same file extension.

   To control the places that are searched in order to
   find the function definition. Set the variable
   ff/depth.

     Default is nil, which only checks the current file
     
     t searches through any open buffers

     'files' searches through files in the current directory.
             This option can be slow"
  (interactive "r")
  (deactivate-mark)
  (block follow
    (if (or (char-equal ?\( (char-after mark-region)) 
            (char-equal ?\( (char-after (1- mark-region)))
            (char-equal ?\( (char-before point-mark)))
        (let (position 
              window
              (extension (file-name-extension (buffer-name)))
              (regex 
               (ff/get-major-mode-keywords
                (buffer-substring-no-properties point-mark mark-region))))
          (if (or (re-search-backward regex nil t) (re-search-forward regex nil t))
              (progn
                (beginning-of-line)
                (return-from follow)))
          (if ff/depth
              (dolist (element (ff/search-open-buffers extension) nil)
                (set-buffer element)
                (if (or (setq position (re-search-forward regex nil t))
                        (setq position (re-search-backward regex nil t)))
                    (progn
                      (ff/display-buffer element position)
                      (return-from follow)))))
          (if (string= ff/depth "files")
              (dolist (element (ff/search-files extension) nil)
                (set-buffer (find-file element))
                (if (setq position (re-search-forward regex nil t))
                    (progn
                      (ff/display-buffer element position)
                      (return-from follow))
                  (kill-buffer element))))
          (message "Could not find the function"))
      (message "Did not detect method call"))))

(defun ff/assemble-regex (function mode &optional stop)
  "Assemble the regex to find the function definition.
   stop is used to identify which languages have different 
   conventions in function definitions"
  (let ((rx "\\(") (list))
    (dolist (element mode list)
      (setq rx 
            (concat rx (mapconcat 'identity (cons element list) " ") "\\|")))
    (if (string= stop "perl")
        (concat (substring rx 0 -2) "\\).* " (replace-regexp-in-string " " "" function) ".*{")
      (concat (substring rx 0 -2) "\\).* " (replace-regexp-in-string " " "" function) " ?("))))

(defun ff/get-major-mode-keywords (function)
  "Get the keywords for the major mode
   to assemble the regex inorder to find
   the function definition"
  (pcase major-mode
    (`java-mode        (ff/assemble-regex function ff/java-definition-keywords)) 
    (`emacs-lisp-mode  (ff/assemble-regex function ff/lisp-definition-keywords))  
    (`python-mode      (ff/assemble-regex function ff/python-definition-keywords))
    (`perl-mode        (ff/assemble-regex function ff/perl-definition-keywords "perl"))
    (`ruby-mode        (ff/assemble-regex function ff/python-definition-keywords))
    (_                 (message "Not a supported major mode"))))
