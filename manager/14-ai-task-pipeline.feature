@ai-pipeline
Feature: AI Task Pipeline
  The AI task system manages requests to the OpenAI API for design generation.
  Tasks are created by DesignGenerator, processed by AiRequestJob, and results
  are stored for JSX transformation.
  Technical: AiTask model with states: pending -> completed. AiRequestJob sends
  requests to OpenAI with structured output (JSON Schema). Results are parsed
  and stored. JsonToJsx converts the JSON tree to JSX. ChatMessages track
  the AI's "thinking" state.

  Background:
    Given the API is configured with a valid OPENAI_API_KEY

  @critical @happy-path
  Scenario: AI task is created during design generation
    Given a design with linked component libraries
    When Design#generate is called
    Then a new AiTask should be created with state "pending"
    And the task should contain the prompt and JSON Schema
    And an AiRequestJob should be enqueued with the task id

  @critical @happy-path
  Scenario: AiRequestJob processes task and updates design
    Given a pending AiTask exists for a design
    When the AiRequestJob runs
    Then the task should call the OpenAI API with the structured output schema
    And the AI response should be stored in the task's result field
    And the task state should change to "completed"
    And the corresponding Iteration should receive the generated JSX
    And the Design status should change to "ready"
    And the ChatMessage should be updated from "thinking" state

  @happy-path
  Scenario: Task API allows external workers to poll and complete tasks
    Given a pending AiTask exists
    When an external worker sends GET /api/tasks/next with valid TASKS_TOKEN
    Then the response should contain the pending task details
    When the worker sends PATCH /api/tasks/:id with result data
    Then the task state should change to "completed"

  @happy-path
  Scenario: Task show endpoint returns JSX
    Given a completed AiTask exists
    When the user sends GET /api/tasks/:id
    Then the response should include the task data with jsx method output

  @error-handling
  Scenario: Task API rejects unauthorized workers
    When a request is sent to GET /api/tasks/next without valid TASKS_TOKEN
    Then the response status should be 401

  @error-handling
  Scenario: AI request failure transitions design to error state
    Given an AiTask is being processed
    When the OpenAI API returns an error
    Then the design status should change to "error"
    And the error should be logged

  @edge-case
  Scenario: No pending tasks returns empty response
    Given no pending AiTasks exist
    When a worker sends GET /api/tasks/next
    Then the response should indicate no tasks available
