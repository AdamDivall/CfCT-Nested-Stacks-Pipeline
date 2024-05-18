#!/bin/sh
printenv CODEBUILD_BUILD_ID

templates=($(ls templates/*/*.yaml))
nested_folder_name="nested"

echo $templates

package_folder="pkgd_templates"

mkdir $package_folder
mkdir $package_folder/templates
mkdir $package_folder/parameters

for template in "${templates[@]}"
do
        file_name=$(basename $template)
        file_name_without_ext=${file_name%.*}
        module_name="$(basename "$(dirname "$template")")"
        echo ">>>>> $module_name"
        echo $file_name_without_ext
        file_path="$(dirname "${template}")"

        #check if delete file exist
        delete_file="$file_path/$file_name_without_ext.delete"

        if [ -e $delete_file ]
        then
                echo "delete flag file: $file_path/$file_name_without_ext.delete found, copying the delete flag file ready for Stack delete in Deploy phase..."
                cp $delete_file $package_folder/templates
        else
                echo "going to package $file_name in path $file_path"
                aws cloudformation package --template $template --s3-bucket $TEMPLATE_BUCKET --output-template-file $package_folder/templates/$file_name

                #Uploading all files in "Nested" folder for StackSet reference
                ls
                ls $file_path/

                aws s3 cp $file_path/$nested_folder_name/ s3://$TEMPLATE_BUCKET/$module_name/$nested_folder_name --recursive

                #check if parameters file exist
                params_file="parameters/$file_name_without_ext-parameters.json"

                if [ -e $params_file ]
                then
                        echo "Params file: $params_file found, copying the params file as well..."
                        cp $params_file $package_folder/parameters
                fi
        fi

done
