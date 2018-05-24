# SharePoint PnP Test Data

Generate large quantities of data using the PnP library for SharePoint Online, 2016 and 2013.

- An easy to install and use PowerShell script with minimal dependencies.
- A simple JSON based specification file.

## Getting Started

Clone the repository.

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

You will need the Microsoft [SharePointPnP.PowerShell Commands](https://github.com/SharePoint/PnP-PowerShell) installed.

### Installing

- Navigate to the folder the repository was downloaded to.
- Test connectivity using the [examples/documents-none.json](examples/documents-none.json) file supplied, this uses the default Documents library but does not insert any items.

### Writing JSON files

The json files use an array as their root object so that multiple lists can be updated using a single file.

```json
[{
    "title": "The title of the list to add test data to",
    "description": "A description of why the test data is being added",
    "rows": "The number of rows to add.",
    "fields": [{
        "title": "The title of the field to have data added",
        "pattern": "The pattern to use to generate the test data"
    }]
}]
```

### Writing Patterns

Patterns are used to generate the data in the fields.

Currently only explicit text is supported.

## Running the tests

Tests are run by using the example json files in the [examples](./examples) folder.

## Contributing

Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/your/project/tags). 

## Authors

* **Sebastian Rogers** - *Initial work* - [sebastianrogers](https://github.com/sebastianrogers)

See also the list of [contributors](https://github.com/sebastianrogers/sharepoint-pnp-test-data/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments
