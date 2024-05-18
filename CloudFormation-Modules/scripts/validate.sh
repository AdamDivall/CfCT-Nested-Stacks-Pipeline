#!/bin/sh
SUCCESS=0
FAILED=1
EXIT_STATUS=$SUCCESS

templates_sub_folder="templates"
parameters_sub_folder="parameters"

set_failed_exit_status() {
  echo "^^^ Caught an error: Setting exit status flag to $FAILED ^^^"
  EXIT_STATUS=$FAILED
}

exit_shell_script() {
  echo "Exiting script with status: $EXIT_STATUS"
  if [[ $EXIT_STATUS == 0 ]]
    then
      echo "INFO: Validation test(s) completed."
      exit $SUCCESS
    else
      echo "ERROR: One or more validation test(s) failed."
      exit $FAILED
    fi
}

templates=($(ls $templates_sub_folder/*/*.yaml && ls $templates_sub_folder/*/*/*.yaml))

for template in "${templates[@]}"
do
        echo "Running aws cloudformation validate-template on $template"
        aws cloudformation validate-template --template-body file://$templates_sub_folder/$template
        if [ $? -ne 0 ]
        then
                echo "ERROR: CloudFormation template failed validation - $template"
                set_failed_exit_status
        fi
        echo "Running cfn_nag_scan on $template"
        cfn_nag_scan --input-path $templates_sub_folder/$template
        if [ $? -ne 0 ]
        then
                echo "ERROR: CFN Nag failed validation - $template"
                set_failed_exit_status
        fi
done

cd $parameters_sub_folder
echo "Changing path to parameters directory: $(pwd)"
for parameter_file_name in $(find . -type f | grep '.json' | grep -v '.j2' | sed 's/^.\///') ; do
    echo "Running json validation on $parameter_file_name"
    python -m json.tool < "$parameter_file_name"
    if [ $? -ne 0 ]
    then
      echo "ERROR: CloudFormation parameter file failed validation - $parameter_file_name"
      set_failed_exit_status
    fi
done
cd ..

# calling return_code function
exit_shell_script
