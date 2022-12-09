#This script will generate a list of commands which can run to delete ELK indices
#No indices are deleted by default. You must execute this script, verify the output, and then separately copy / run the resultant output.
#The purpose of this additional step is to reduce the possibility of acorpdental deletion
#Update the $elk_host value depending on use case
$elk_host = "http://elk.corp.io"
#Update matcher string ("*corpapplogs*" as shown below) depending on use case
$index_array = curl $elk_host":9200/_cat/indices?v`&s=index" | %{$_.rawcontent -split "  "} | ?{$_ -like "*corpapplogs*"}
#Modify the array index value below to change the number of entries returned
$removal_candidates =  $index_array[0..$($index_array.count - 30)] -replace " ",""
$removal_candidates | %{"Invoke-WebRequest -method DELETE "+"$elk_host"+":9200/$_"}

<#
If the elk server ran out of space, then you may see the following error displayed when getting elastic service status
"retrying failed action with response code: 403"

The following curl command can be run locally on the ELK server to resolve 403 issue referenced above:

curl -X PUT "http://localhost:9200/_all/_settings?pretty" -H 'Content-Type: application/json' -d'
{
    "index.blocks.read_only_allow_delete": null
}'
#>
