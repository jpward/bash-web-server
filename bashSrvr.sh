#!/bin/bash

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

THIS_SCRIPT="$(basename $0)"

MODE="$1"
DEBUG=${DEBUG:-false}

htmlDecode()
{
  echo $1 | python3 -c 'import urllib.parse, sys; [print(urllib.parse.unquote(l), end="") for l in sys.stdin]'
}

if ! [ -z "${MODE}" ] && [ ${MODE} = "pipe" ]; then
  read INPUT
  if $DEBUG; then
    echo ${INPUT} > /tmp/bashSrvrDebug.txt
  fi
  if ( echo ${INPUT} | grep -q "GET /email[ ?]" ); then
    echo -e 'HTTP/1.1 200 OK\r\n'
    #echo -e 'Connection: close\r\n\r\n'
    echo '<!DOCTYPE html>'
    echo '<html>'
    echo '<body>'
    echo ''
    echo '<h1>Email message</h1>'
    echo ''
    echo '<p>Email message to person on dropdown</p>'
    echo ''
    echo '<form action="/person">'
    echo '  <label for="person">To:</label>'
    echo '  <select name="person" id="person">'
    echo '    <option value="One">One</option>'
    echo '    <option value="Two">Two</option>'
    echo '  </select>'
    echo '  <label for="msg">Subject:</label><br>'
    echo '  <input type="text" id="subj" name="subj" value="subject"><br>'
    echo '  <label for="msg">Message:</label><br>'
    echo '  <input type="text" id="msg" name="msg" value="message"><br>'
    echo '  <br><br>'
    echo '  <input type="submit" value="Submit">'
    echo '</form>'
    echo ''
    echo '</body>'
    echo '</html>'
  elif ( echo ${INPUT} | grep -q "GET /person[ ?]" ); then
    echo -e 'HTTP/1.1 200 OK\r\n'
    echo 'E-mailing...'
    PERSON="$(echo ${INPUT} | grep -oP '\?person=.*?&' | cut -d'=' -f2 | sed 's/&$//')"
    echo 'Person: '$PERSON
    SUBJ="$(htmlDecode "$(echo ${INPUT} | grep -oP '&subj=.*&' | cut -d'=' -f2 | sed -e 's/&$//' -e 's/+/ /g')")"
    echo 'Subject: '$SUBJ
    MSG="$(htmlDecode "$(echo ${INPUT} | grep -oP '&msg=.* ' | cut -d'=' -f2 | sed -e 's/ $//' -e 's/+/ /g')")"
    echo 'Message: '$MSG

    FROM=from@gmail.com
    FROM_TXT="\"Name One\" <${FROM}>"
    TO=$FROM
    TO_TXT=${FROM_TXT}
    if ( echo ${PERSON} | grep -q Two ); then
      TO=To_Two@gmail.com
      TO_TXT="\"Name Two\" <${TO}>"
    fi
    echo "From: ${FROM_TXT}" > /tmp/bmail.txt
    echo "To: ${TO_TXT}" >> /tmp/bmail.txt
    echo "Subject: $SUBJ" >> /tmp/bmail.txt
    echo "" >> /tmp/bmail.txt
    echo $MSG >> /tmp/bmail.txt

    if true; then
      curl --url 'smtps://smtp.gmail.com:465' --ssl-reqd \
      --mail-from ${FROM} --mail-rcpt ${TO} \
      --upload-file /tmp/bmail.txt --user 'from@gmail.com:password' \
      --insecure --silent --output /dev/null
    fi
  else
    echo -e 'HTTP/1.1 404 page not found\r\n'
  fi
else
  FIFO=/tmp/bfifo
  PORT=7777
  sudo rm -f ${FIFO}
  sudo mknod -m 777 ${FIFO} p
  RUN=true
  while $RUN; do
    cat ${FIFO} | nc -l -p ${PORT} | ${HERE}/${THIS_SCRIPT} pipe > ${FIFO}
  done
fi

