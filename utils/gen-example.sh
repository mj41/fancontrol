#!/bin/bash

if [ -e examples-temp.txt ]; then
  echo "Can't run. Temp file examples-temp.txt already exists."
  echo ""
  echo "Help commands"
  echo "  clear && cat examples-temp.txt && utils/gen-example.sh"
  echo "  mv examples-temp.txt examples.txt"
  echo "  rm examples-temp.txt"
  exit
fi

echo "Some examples:" > examples-temp.txt
echo "" >> examples-temp.txt

echo "#> perl fancontrol.pl --ver=3" >> examples-temp.txt
echo "ToDo #1 - put output of 'clear && perl fancontrol.pl --ver=3' here!!!" >> examples-temp.txt
echo "" >> examples-temp.txt
echo "" >> examples-temp.txt


echo "#> perl fancontrol.pl --help" >> examples-temp.txt
perl fancontrol.pl --help | tee -a examples-temp.txt
echo "" >> examples-temp.txt
echo "" >> examples-temp.txt


echo "#> perl fancontrol.pl --daemon-start" >> examples-temp.txt
perl fancontrol.pl --daemon-start | tee -a examples-temp.txt
echo "" >> examples-temp.txt

echo "#> cat '/var/run/fancontrol-perl.pid'" >> examples-temp.txt
cat '/var/run/fancontrol-perl.pid' | tee -a examples-temp.txt
echo "" >> examples-temp.txt

echo "#> perl fancontrol.pl --daemon-start" >> examples-temp.txt
perl fancontrol.pl --daemon-start | tee -a examples-temp.txt
echo "" >> examples-temp.txt

echo "#> perl fancontrol.pl --daemon-stop" >> examples-temp.txt
perl fancontrol.pl --daemon-stop | tee -a examples-temp.txt
echo "" >> examples-temp.txt

echo "#> perl fancontrol.pl --ver=10" >> examples-temp.txt
echo "ToDo #2 - put output of 'clear && perl fancontrol.pl --ver=10' here!!!" >> examples-temp.txt
echo "" >> examples-temp.txt

echo "Run "
echo "  clear && perl fancontrol.pl --ver=3"
echo "and put output to examples-temp.txt on ToDo #1 mark, then run"
echo "  clear && perl fancontrol.pl --ver=10"
echo "and put output to examples-temp.txt on ToDo #2 mark."
echo "Then run 'mv examples-temp.txt examples.txt'"

