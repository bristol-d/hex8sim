@ECHO OFF
REM Create a html file from the markdown sources.
type html-header > %1.html
multimarkdown --nolabels %1.md >> %1.html
type html-footer >> %1.html
