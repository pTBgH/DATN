<?php

namespace App\Traits;

trait HasCompositePrimaryKey
{
    public $incrementing = false;

    protected function setKeysForSaveQuery($query)
    {
        foreach ($this->getPrimaryKey() as $keyField) {
            $query->where($keyField, '=', $this->getAttribute($keyField));
        }
        return $query;
    }

    public function getKey()
    {
        return array_map(fn($key) => $this->getAttribute($key), $this->getPrimaryKey());
    }

    public function getPrimaryKey()
    {
        return is_array($this->primaryKey) ? $this->primaryKey : [$this->primaryKey];
    }

    public function getKeyName()
    {
        return $this->primaryKey;
    }
}
