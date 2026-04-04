<?php

namespace App\Workflow\Nodes;

interface WorkflowNodeInterface
{
    public function getType(): string;
    public function execute(array $inputData, array $parameters): array;
}