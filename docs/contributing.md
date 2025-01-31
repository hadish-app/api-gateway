# Contributing to API Gateway

Thank you for your interest in contributing to our API Gateway project! This document provides guidelines and workflows for contributing to the project effectively.

## Branch Naming Convention

- Feature branches: `feature/<feature-name>`
- Bug fixes: `fix/<bug-description>`
- Documentation: `docs/<doc-description>`
- Performance improvements: `perf/<description>`

## Development Process

1. Create a new branch from `main` for your changes
2. Make your changes following the code style guidelines
3. Write or update tests as needed
4. Ensure all tests pass locally
5. Commit your changes with clear, descriptive commit messages
6. Push your branch and create a Pull Request

## Code Style Guidelines

### Lua Code Style

- Use 4 spaces for indentation
- Follow Lua naming conventions:
  - `local_variables` in snake_case
  - `ModuleNames` in PascalCase
  - `functionNames` in camelCase
- Add comments for complex logic
- Keep functions focused and single-purpose
- Document public APIs and functions

### Configuration Style

- Follow NGINX configuration best practices
- Keep location blocks organized and well-documented
- Use meaningful names for upstream servers and locations

## Pull Request Process

### 1. Before Submitting

- Ensure all tests pass
- Update documentation if needed
- Review your changes for code style compliance
- Verify your branch is up to date with main

### 2. PR Description

- Provide a clear title and description
- Reference any related issues
- List significant changes
- Include any necessary deployment notes

### 3. PR Requirements

- Clean commit history
- Passing CI/CD checks
- No merge conflicts
- Appropriate test coverage
- Documentation updates if needed

## Code Review Process

### Review Criteria

Reviewers will evaluate:

- Code functionality and correctness
- Test coverage and quality
- Documentation completeness
- Performance implications
- Security considerations
- Adherence to coding standards

### Review Workflow

1. **Author**

   - Respond to feedback promptly
   - Make requested changes
   - Request re-review when ready

2. **Reviewers**

   - Review within 2 business days
   - Provide constructive feedback
   - Focus on:
     - Logic and functionality
     - Error handling
     - Security implications
     - Performance considerations
     - Code style and documentation

3. **Approval Process**
   - Requires at least one approval from maintainers
   - All comments must be resolved
   - CI/CD checks must pass

### After Merge

- DO NOT Delete the feature branch
- Update relevant documentation
- Monitor deployment and verify functionality

## Questions or Need Help?

If you have questions or need assistance:

- Open an issue for discussion
- Reach out to project maintainers
- Check existing documentation and issues

Thank you for contributing to our API Gateway project!
