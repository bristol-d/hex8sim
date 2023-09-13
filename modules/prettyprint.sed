# use: sed -f [this file] -i [document]

s/^\(--.*\)/<span class="comment">\1<\/span>/
s/ \(--.*\)/ <span class="comment">\1<\/span>/
s/>\(--.*\)/><span class="comment">\1<\/span>/
s/\(0x[0-9A-F][0-9A-F]:\)/<span class="address">\1<\/span>/
s/\(0x[0-9A-Fa-f]\+ &lt;[+][0-9]\+&gt;:\)/<span class="address">\1<\/span>/
s/\(LDAC\|LDBC\|LDAM\|LDBM\|ADD\|SUB\|STAM\|BR\|BRN\|BRZ\|PFIX\|LDAI\|LDAP\|LDBI\|STAI\|BRB\)/<span class="instruction">\1<\/span>/g
s/\(push\|pop\|mov\|add\|sub\|lea\|cmp\|jmp\|je\|jne\|call\|ret\|leave\)\b/<span class="instruction">\1<\/span>/g
s/\b\([er]\(ax\|bx\|cx\|dx\|si\|di\|sp\|bp\)\)\b/<span class="register">\1<\/span>/g
