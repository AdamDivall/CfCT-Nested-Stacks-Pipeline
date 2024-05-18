#!/bin/sh
export IFS=$'\n'

packaged_folder="pkgd_templates"
templates_sub_folder="templates"
parameters_sub_folder="parameters"

if [ $NESTED_STACK_TEMPLATE_UPDATES == "True" ]
then
        echo -e "nested stack auto updates enabled setting version parameter: pGLCTSolutionVersion=$CODEBUILD_BUILD_ID"
        version_parameter="pGLCTSolutionVersion=$CODEBUILD_BUILD_ID "
else
        version_parameter="pGLCTSolutionVersion=$SOLUTION_VERSION "
fi

cd $packaged_folder
templates=($(ls $templates_sub_folder))

for template in "${templates[@]}"
do
        echo "processing $template"
        #check if additional files exist
        params_file="${template%.*}-parameters.json"
        delete_file="${template%.*}.delete"
        #reset parameters
        parameters=$version_parameter
        if [ -e $templates_sub_folder/$delete_file ]
        then
                echo -e "\nchecking for ${template%.*} stack"
                StackId=$(aws cloudformation describe-stacks --stack-name ${template%.*} --query 'Stacks[].StackId' --output text 2> /dev/null)
                if [ $StackId ]
                then
                        echo -e "\nfound stack $StackId"
                        echo "deleting ${template%.*}"
                        aws cloudformation delete-stack --stack-name ${template%.*}
                else
                        echo -e "\nstack not found"
                        echo "stack doesnt exist, you can now delete any templates for ${template%.*} from the repo"
                fi
        elif [ -e $parameters_sub_folder/$params_file ]
        then
                parameters+=$(jq -r '.[] | [.ParameterKey, .ParameterValue] | "\(.[0])=\(.[1])"' $parameters_sub_folder/$params_file)
                echo -e "\nfound $parameters_sub_folder/$params_file"
                echo "deploying ${template%.*} with parameters file"
                aws cloudformation deploy --template-file $templates_sub_folder/$template --parameter-overrides ${parameters[@]} --stack-name ${template%.*} --capabilities CAPABILITY_NAMED_IAM --role-arn $ROLE_ARN
        else
                echo "deploying ${template%.*} without passing in parameters file"
                echo "parameters file: $params_file not found in $parameters_sub_folder folder"
                aws cloudformation deploy --template-file $templates_sub_folder/$template --parameter-overrides ${parameters[@]} --stack-name ${template%.*} --capabilities CAPABILITY_NAMED_IAM --role-arn $ROLE_ARN
        fi

done
