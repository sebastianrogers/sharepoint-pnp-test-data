# SharePoint PnP Test Data

Generate large quantities of data using the PnP library for SharePoint Online, 2019, 2016 and 2013.

- An easy to install and use PowerShell script with minimal dependencies.
- A simple JSON based specification file.
- Utilties to transfer data between SharePoint sites.
- Uses the ETL (Export Transform Load) model.

## Functionality

### Creating SharePoint Import Files (New-Data.ps1)

Randomly generate data that can be imported via Set-Data.ps1.

This uses a json definition file that will be processed by the New-Data.ps1 script to generate a CSV file suitable for uploading via Set-Data.ps1.

```json
{
    "title": "Human readable title for the definition.",
    "description": "Description of what the definition will generate.",
    "lists": [
        {
            "rows": "1", // The number of rows to generate
            "fields": [
                {
                    "title": "The InternalName of the field",
                    "pattern": "The pattern to use to generate the field"
                }
            ]
        }
    ],
    "lookups": {
        "token": [
            // The token name that the {lookup:} token will use
            "value"
        ]
    }
}
```

#### Field Patterns

The field pattern is the data used to populate a field.

It can comprise:

-   Tokens
-   Regular expressions

The tokens are evaluated first in the following order.

-   {telephone}, generates a string in the format "09999 999999"
-   {lookup:name.field}, replaces the token with a random value from the matching lookup member, e.g. "{lookup:forename.title}"
-   {field:name}, replaces the token with the value of the field in the current item, e.g. "{field:forename}"

### Exporting SharePoint Site (Export-Site.ps1)

There is a helper function that will allow you to export an entire SharePoint Site to a folder.

Each non hidden list will be exported as a csv file in the folder specified by the Path parameter

```ps1
Connect-PnPOnline https://<tenant>.sharepoint.com/sites/Demo
.\Export-Site.ps1 -Path:.\temp -URL:ttps://<tenant>.sharepoint.com/sites/Demo
```

The page size used to batch the exports can be modified by using the -PageSize parameter.

### Exporting SharePoint Lists (Export-List.ps1)

Export data from an existing SharePoint List

```ps1
Connect-PnPOnline https://<tenant>.sharepoint.com/sites/Demo
.\Export-List.ps1 -Identity:Documents | Export-Csv -Path:.\temp\Documents.csv -NoTypeInformation
```

The page size used to batch the exports can be modified by using the -PageSize parameter.

Optionally you can specify a list of fields to export by using their internal names

```ps1
Connect-PnPOnline https://<tenant>.sharepoint.com/sites/Demo
.\Export-List.ps1 -Identity:Documents -Fields:@("Title", "Name") | Export-Csv -Path:.\temp\Documents.csv -NoTypeInformation
```

### Transforming Files (Convert-Files.ps1)

This script allows you to convert the data in a set of csv files by transforming it.

The transformed files are copied to a folder so that the original files are not updated.

| Transform | Effect                                                                                                 |
| --------- | ------------------------------------------------------------------------------------------------------ |
| lookup    | Replaces the field value with the matching value from the lookup if there is a match                   |
| md5       | Replaces the field value with its md5 hash, this in effect anonymises it but preerves its distinctness |
| remove    | Removes the field from the output                                                                      |

The transform definition is a json file that lists the mappings to use and optionally any lookups

```json
{
    "mapping": {
        "field-name": {
            "type": "lookup|md5",
            "lookup" "lookup-name"
        },
    "lookup": {
        "lookup-name": {
            "source-value": "target-value"
        }
    }
```

- field-name, the name of the column in the csv file
- type, the type of transform
- lookup, optional used with the lookup transform and is the lookup-name under the lookup element to use
- lookup-name, the name of the lookup to use
- source-value, when a value matches use the corresponding target-value in the transformed file
- target-value, the value to replace the source-value with

```ps1
.\Convert-Folder.ps1 -SourcePath:.\exported -TransformPath:.\transform.json -TargetPath:.\transformed
```

## Getting Started

Clone the repository.

Install the PnP PowerShell module

```ps1
Install-Module SharePointPnPPowerShellOnline
```

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

You will need the Microsoft [SharePointPnP.PowerShell Commands](https://github.com/SharePoint/PnP-PowerShell) installed.

### Installing

-   Navigate to the folder the repository was downloaded to.
-   Test connectivity using the [examples/documents-none.json](examples/documents-none.json) file supplied, this uses the default Documents library but does not insert any items.

### Writing JSON files

The json files use an array as their root object so that multiple lists can be updated using a single file.

```json
[
    {
        "title": "The title of the list to add test data to",
        "description": "A description of why the test data is being added",
        "rows": "The number of rows to add.",
        "fields": [
            {
                "title": "The title of the field to have data added",
                "pattern": "The pattern to use to generate the test data"
            }
        ]
    }
]
```

### Writing Patterns

Patterns are used to generate the data in the fields.

Currently only explicit text is supported.

## Running the tests

Tests are run by using the example csv files in the [examples](./examples) folder.

They require a SharePoint Site with an Example list.

```ps1
Connect-PnPOnline -Url:https://<tenant>.sharepoint.com/sites/Demo -UseWeb
.\Set-Data.ps1 -Path:.\examples\example.csv -Verbose
```

## Contributing

Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags).

## Authors

-   **Sebastian Rogers** - _Initial work_ - [sebastianrogers](https://github.com/sebastianrogers)

See also the list of [contributors](https://github.com/sebastianrogers/sharepoint-pnp-test-data/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments
