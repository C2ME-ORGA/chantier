<?php

namespace Tests\Architecture\Support;

use PhpParser\Node;
use PhpParser\NodeVisitor;

/**
 * Collects statically observable class references from a resolved PHP AST.
 *
 * Namespace declarations, function/constant imports and global function or
 * constant fetches are ignored because they do not designate classes.
 */
final class PhpReferenceCollector implements NodeVisitor
{
    /**
     * @var array<string, true>
     */
    public array $references = [];

    /**
     * @var array<int, true>
     */
    private array $ignoredNames = [];

    public function beforeTraverse(array $nodes)
    {
        return null;
    }

    public function enterNode(Node $node)
    {
        if ($node instanceof Node\Stmt\Namespace_ && $node->name instanceof Node\Name) {
            $this->ignoredNames[spl_object_id($node->name)] = true;
        }

        if ($node instanceof Node\Stmt\Use_ && $node->type !== Node\Stmt\Use_::TYPE_NORMAL) {
            foreach ($node->uses as $use) {
                $this->ignoredNames[spl_object_id($use->name)] = true;
            }
        }

        if ($node instanceof Node\Stmt\GroupUse) {
            $prefix = $node->prefix->toString();
            $this->ignoredNames[spl_object_id($node->prefix)] = true;

            foreach ($node->uses as $use) {
                $type = $use->type === Node\Stmt\Use_::TYPE_UNKNOWN ? $node->type : $use->type;
                $name = $use->name->toString();

                $this->ignoredNames[spl_object_id($use->name)] = true;

                if ($type === Node\Stmt\Use_::TYPE_NORMAL) {
                    $reference = str_starts_with($name, $prefix.'\\') ? $name : $prefix.'\\'.$name;
                    $this->references[$reference] = true;
                }
            }
        }

        if (
            ($node instanceof Node\Expr\FuncCall || $node instanceof Node\Expr\ConstFetch)
            && $node->name instanceof Node\Name
        ) {
            $this->ignoredNames[spl_object_id($node->name)] = true;
        }

        if ($node instanceof Node\Name && ! isset($this->ignoredNames[spl_object_id($node)])) {
            $this->references[$node->toString()] = true;
        }

        return null;
    }

    public function leaveNode(Node $node)
    {
        return null;
    }

    public function afterTraverse(array $nodes)
    {
        return null;
    }
}
